# Part of the Crubit project, under the Apache License v2.0 with LLVM
# Exceptions. See /LICENSE for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

load("@rules_rust//rust/private:repositories.bzl", "rust_repository_set", "rust_register_toolchains", "DEFAULT_TOOLCHAIN_TRIPLES")
load("@rules_rust//rust/private:repository_utils.bzl", "DEFAULT_STATIC_RUST_URL_TEMPLATES")
load("@rules_rust//rust/platform:triple.bzl", "get_host_triple")
load("@toolchains_llvm//toolchain:rules.bzl", "llvm_toolchain")
load("//bazel:versions.bzl", "LLVM_MAP")

def _crubit_toolchains_impl(ctx):
    # Default toolchain configurations
    rust_version = "nightly/2026-05-31"
    llvm_version = None
    llvm_extra_distributions = {}
    dev_components = True
    
    user_llvm_repo = None
    user_rust_repo = None

    # Detect the host triple as a reasonable default for exec_triple.
    exec_triple = get_host_triple(ctx).str

    # Read tags from the root module (or downstream modules)
    for mod in ctx.modules:
        for config in mod.tags.configure:
            if config.rust_version:
                rust_version = config.rust_version

    # 1. Define the LLVM repository.
    # It must be named "llvm_toolchain" to satisfy Crubit's default internal label references.
    if user_llvm_repo:
        pass
    else:
        mapped_config = LLVM_MAP.get(rust_version, {})
        final_llvm_version = llvm_version or mapped_config.get("version", "21.1.8")
        final_sha256 = mapped_config.get("sha256")
        final_urls = mapped_config.get("urls")
        final_strip_prefix = mapped_config.get("strip_prefix")

        if final_urls:
            llvm_toolchain(
                name = "llvm_toolchain",
                llvm_version = final_llvm_version,
                urls = {"": final_urls},
                sha256 = {"": final_sha256},
                strip_prefix = {"": final_strip_prefix},
            )
        else:
            llvm_toolchain(
                name = "llvm_toolchain",
                llvm_version = final_llvm_version,
                extra_llvm_distributions = llvm_extra_distributions,
            )

    # 2. Define the Rust repository.
    if not user_rust_repo:
        toolchain_triples = dict(DEFAULT_TOOLCHAIN_TRIPLES)
        rust_register_toolchains(
                hub_name = "rust_toolchains",
                dev_components = True,
                edition = "2024",
                extra_rustc_flags = [],
                extra_exec_rustc_flags = [],
                allocator_library = None,
                global_allocator_library = None,
                rustfmt_version = rust_version,
                rust_analyzer_version = None,
                sha256s = None,
                extra_target_triples = [],
                opt_level = None,
                strip_level = None,
                urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
                versions = [rust_version],
                compact_windows_names = True,
                aliases = {},
                toolchain_triples = toolchain_triples,
                rustfmt_toolchain_triples = DEFAULT_TOOLCHAIN_TRIPLES,
                target_settings = [str(v) for v in []],
                extra_toolchain_infos = {},
            )

crubit_toolchains = module_extension(
    implementation = _crubit_toolchains_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = {
                "rust_version": attr.string(doc = "The version of Rust to install."),
            }
        )
    }
)
