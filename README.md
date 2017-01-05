# fuse

Bindings to libFUSE.  Not feature complete yet.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  fuse:
    github: Papierkorb/fuse
```

Then make sure to have `libfuse` installed. It is a **development** and a
**runtime** dependency.

## Usage

See `samples/`

## Missing

* Wrap write-access methods
* Figure out how to test this

## Contributing

1. Fork it ( https://github.com/Papierkorb/fuse/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [Papierkorb](https://github.com/Papierkorb) Stefan Merettig - creator, maintainer
