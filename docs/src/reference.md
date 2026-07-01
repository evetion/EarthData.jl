```@meta
CurrentModule = EarthData
```

# API reference

## Index

```@index
```

## Public API

```@autodocs
Modules = [EarthData]
Order = [:function, :type, :constant]
Private = true
```

## UMM-G schema types

Granule search results are parsed as `EarthData.Granules.UMM_G` and related
schema types generated from NASA's UMM-G schema.

```@autodocs
Modules = [EarthData.Granules]
Order = [:type]
Private = true
```

## UMM-C schema types

Collection search results are parsed as `EarthData.Collections.UMM_C` and
related schema types generated from NASA's UMM-C schema.

```@autodocs
Modules = [EarthData.Collections]
Order = [:type]
Private = true
```
