# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2022-11

### Added
* `:event` opt for `Statechart.state/3` and `Statechart.statechart/2`

### Removed
* `Statechart.>>>`

## [0.2.0] - 2022-11-27

### Added
* `:entry` and `:exit` opts for `Statechart.state/3`
* `:entry` and `:context` opts for `Statechart.statechart/2`
* `Statechart.context/1`

## [0.1.0] - 2022-11-06

### Added
* `Statechart.>>>`
* `Statechart.state/3`
  * `:default` opt
* `Statechart.statechart/2`
  * `:default` and `:module` opts
* `Statechart.in_state?/2`
* `Statechart.last_event_status/1`
* `Statechart.states/1`
* `Statechart.trigger/2`

[0.3.0]: https://github.com/jonathanchukinas/statechart/releases/tag/v0.3.0
[0.2.0]: https://github.com/jonathanchukinas/statechart/releases/tag/v0.2.0
[0.1.0]: https://github.com/jonathanchukinas/statechart/releases/tag/v0.1.0
