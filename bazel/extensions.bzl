# Part of the Crubit project, under the Apache License v2.0 with LLVM
# Exceptions. See /LICENSE for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

load("@rules_rust//rust/private:repositories.bzl", "rust_register_toolchains", "DEFAULT_TOOLCHAIN_TRIPLES")
load("@rules_rust//rust/private:repository_utils.bzl", 
    "DEFAULT_STATIC_RUST_URL_TEMPLATES", 
    "DEFAULT_EXTRA_TARGET_TRIPLES",
    "DEFAULT_NIGHTLY_VERSION")
load("@rules_rust//rust/platform:triple.bzl", "get_host_triple")
load("@toolchains_llvm//toolchain:rules.bzl", "llvm_toolchain")
load("//bazel:versions.bzl", "LLVM_MAP")

# These attributes are mirrored from rules_rust's toolchain tag to allow 
# configuration without duplicating the implementation logic.
_RUST_TAG_ATTRS = {
    "rust_version": attr.string(doc = "The version of Rust to install."),
    "edition": attr.string(doc = "The rust edition to be used by default.", default = "2024"),
    "dev_components": attr.bool(doc = "Whether to download the rustc-dev components.", default = True),
    "extra_rustc_flags": attr.string_list(doc = "Extra flags to pass to rustc in non-exec configuration."),
    "extra_exec_rustc_flags": attr.string_list(doc = "Extra flags to pass to rustc in exec configuration."),
    "rustfmt_version": attr.string(doc = "The version of rustfmt."),
    "rust_analyzer_version": attr.string(doc = "The version of rust-analyzer."),
    "sha256s": attr.string_dict(doc = "A dict associating tool subdirectories to sha256 hashes."),
    "extra_target_triples": attr.string_list(doc = "Additional rust-style targets.", default = DEFAULT_EXTRA_TARGET_TRIPLES),
    "opt_level": attr.string_dict(doc = "Rustc optimization levels."),
    "strip_level": attr.string_dict(doc = "Rustc strip levels."),
    "urls": attr.string_list(doc = "A list of mirror urls.", default = DEFAULT_STATIC_RUST_URL_TEMPLATES),
    "allocator_library": attr.label(doc = "Target that provides allocator functions."),
    "global_allocator_library": attr.label(doc = "Target that provides allocator functions when global allocator is used."),
    "target_settings": attr.label_list(doc = "Config settings for toolchain selection."),
    "aliases": attr.string_dict(doc = "Toolchain repository aliases."),
}

_LLVM_TAG_ATTRS = {
    "llvm_version": attr.string(doc = "The version of LLVM to install."),
    "llvm_urls": attr.string_list(doc = "Custom URLs for LLVM distribution."),
    "llvm_sha256": attr.string(doc = "SHA256 for LLVM distribution."),
    "llvm_strip_prefix": attr.string(doc = "Strip prefix for LLVM distribution."),
}

def _crubit_toolchains_impl(ctx):
    # Prefer configuration from the root module.
    config = None
    for mod in ctx.modules:
        if mod.is_root and mod.tags.configure:
            config = mod.tags.configure[0]
            break
    if not config:
        for mod in ctx.modules:
            if mod.tags.configure:
                config = mod.tags.configure[0]
                break

    # 1. Coordinate versions
    rust_version = (config.rust_version if config else None) or "nightly/2026-05-31"
    mapped_config = LLVM_MAP.get(rust_version, {})
    
    # 2. Define LLVM repository
    final_llvm_version = (getattr(config, "llvm_version", None) or 
                          mapped_config.get("version", "21.1.8"))
    final_urls = (getattr(config, "llvm_urls", None) or 
                  mapped_config.get("urls"))
    final_sha256 = (getattr(config, "llvm_sha256", None) or 
                    mapped_config.get("sha256"))
    final_strip_prefix = (getattr(config, "llvm_strip_prefix", None) or 
                          mapped_config.get("strip_prefix"))

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
        )

    # 3. Define Rust repository (delegated to rules_rust)
    rust_kwargs = {}
    if config:
        rust_kwargs = {k: getattr(config, k) for k in _RUST_TAG_ATTRS.keys() if k != "rust_version"}
    else:
        # Defaults if no configure tag is present
        rust_kwargs = {
            "edition": "2024",
            "dev_components": True,
            "extra_target_triples": DEFAULT_EXTRA_TARGET_TRIPLES,
            "urls": DEFAULT_STATIC_RUST_URL_TEMPLATES,
        }

    # Stringify labels as required by the underlying repository rules
    if rust_kwargs.get("allocator_library"):
        rust_kwargs["allocator_library"] = str(rust_kwargs["allocator_library"])
    if rust_kwargs.get("global_allocator_library"):
        rust_kwargs["global_allocator_library"] = str(rust_kwargs["global_allocator_library"])
    if rust_kwargs.get("target_settings"):
        rust_kwargs["target_settings"] = [str(s) for s in rust_kwargs["target_settings"]]

    rust_register_toolchains(
        hub_name = "rust_toolchains",
        versions = [rust_version],
        toolchain_triples = dict(DEFAULT_TOOLCHAIN_TRIPLES),
        rustfmt_toolchain_triples = DEFAULT_TOOLCHAIN_TRIPLES,
        compact_windows_names = True,
        **rust_kwargs
    )

crubit_toolchains = module_extension(
    implementation = _crubit_toolchains_impl,
    tag_classes = {
        "configure": tag_class(
            attrs = _RUST_TAG_ATTRS | _LLVM_TAG_ATTRS
        )
    }
)
