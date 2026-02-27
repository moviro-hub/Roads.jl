# Roads.jl

This package provides a collection of tools, like osmium and OSRM, for working with road networks.

**Note**: This package is a work in progress and it's a API is subject to change.

## Current Features
The package provides the following functionality:
- Subsetting OSM data
- Creating OSRM road network from OSM data
- Snapping locations to the road network
- Finding routes between locations
- Finding distance/duration matrices between multiple locations

## Releasing

Merge to main, then:

```bash
git tag -a v0.2.2 -m "Release v0.2.2" && git push origin v0.2.2
```
this will trigger a release action that will create a new release on GitHub.
