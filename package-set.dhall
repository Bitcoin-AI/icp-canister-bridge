let base = https://github.com/internet-computer/base-package-set/releases/download/moc-0.7.4/package-set.dhall sha256:3a20693fc597b96a8c7cf8645fda7a3534d13e5fbda28c00d01f0b7641efe494
let Package = { name : Text, version : Text, repo : Text, dependencies : List Text }

let additions = [
  { name = "json"
  , repo = "https://github.com/aviate-labs/JSON.mo"
  , version = "v0.2.1"
  , dependencies = [ "base-0.7.3" ] : List Text
  },

  { name = "base", 
      repo = "https://github.com/dfinity/motoko-base", 
      version = "f8112331eb94dcea41741e59c7e2eaf367721866", 
      dependencies = [] : List Text
  },
  { name = "parser-combinators"
    , repo = "https://github.com/aviate-labs/parser-combinators.mo"
    , version = "v0.1.0"
  , dependencies = [ "base-0.7.3" ] : List Text
    },
  { name = "evm-tx"
    , repo = "https://github.com/av1ctor/evm-txs.mo"
    , version = "v0.1.3"
  , dependencies = [ "base" ] : List Text
    },
        { 
      name = "sha3", 
      repo = "https://github.com/hanbu97/motoko-sha3", 
      version = "v0.1.1", 
      dependencies = [] : List Text
    },
    { 
      name = "rlp", 
      repo = "https://github.com/relaxed04/rlp-motoko", 
      version = "master", 
      dependencies = [] : List Text
    },
    { 
      name = "libsecp256k1", 
      repo = "https://github.com/av1ctor/libsecp256k1.mo", 
      version = "main", 
      dependencies = ["base-0.7.3"] : List Text
    },
] : List Package

in  base # additions