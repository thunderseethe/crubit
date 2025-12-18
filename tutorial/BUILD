load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_rust//rust:rust_library.bzl", "rust_library")
load(
    "//cc_bindings_from_rs/bazel_support:cc_bindings_from_rust_rule.bzl",
    "cc_bindings_from_rust",
)

cc_binary(
    name = "hello-world",
    srcs = ["hello-world.cpp"],
    deps = [":lib_cc_api"],
)

rust_library(
  name = "lib",
  srcs = ["lib.rs"],
)

cc_bindings_from_rust(
    name = "lib_cc_api",
    crate = ":lib",
)

