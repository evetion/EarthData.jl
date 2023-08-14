abstract type AbstractJSON end

"This element stores a track pass and its tile information. It will allow a user to search by pass number and their tiles that are contained with in a cycle number.  While trying to keep this generic for all to use, this comes from a SWOT requirement where a pass represents a 1/2 orbit. This element will then hold a list of 1/2 orbits and their tiles that together represent the granules spatial extent."
struct TrackPassTileType <: AbstractJSON
	"A tile is a subset of a pass' spatial extent. This element holds a list of tile identifiers that exist in the granule and will allow a user to search by tile identifier that is contained within a pass number within a cycle number. Though intended to be generic, this comes from a SWOT mission requirement where a tile is a spatial extent that encompasses either a square scanning swath to the left or right of the ground track or a rectangle that includes a full scanning swath both to the left and right of the ground track."
	Tiles::Union{Nothing, Vector{String}}
	"A pass number identifies a subset of a granule's spatial extent. This element holds a pass number that exists in the granule and will allow a user to search by pass number that is contained within a cycle number.  While trying to keep this generic for all to use, this comes from a SWOT requirement where a pass represents a 1/2 orbit."
	Pass::Int64
end
StructTypes.StructType(::Type{TrackPassTileType}) = StructTypes.Struct()


"This entity holds all types of online URL associated with the granule such as guide document or ordering site etc."
struct RelatedUrlType <: AbstractJSON
	"The format that granule data confirms to. While the value is listed as open to any text, CMR requires that it confirm to one of the values on the GranuleDataFormat values in the Keyword Management System: https://gcmd.earthdata.nasa.gov/kms/concepts/concept_scheme/GranuleDataFormat"
	Format::Union{Nothing, String}
	"Description of the web page at this URL."
	Description::Union{Nothing, String}
	"A keyword that provides more detailed information than Type of the online resource to this resource. For example if the Type=VIEW RELATED INFORMATION then the Subtype can be USER'S GUIDE or GENERAL DOCUMENTATION"
	Subtype::Union{Nothing, String}
	"The URL for the relevant resource."
	URL::String
	"A keyword describing the type of the online resource to this resource."
	Type::String
	"The mime type of the resource."
	MimeType::Union{Nothing, String}
	"The unit of the file size."
	SizeUnit::Union{Nothing, String}
	"The size of the resource."
	Size::Union{Nothing, Float64}
end
StructTypes.StructType(::Type{RelatedUrlType}) = StructTypes.Struct()


"Information about any physical constraints for accessing the data set."
struct AccessConstraintsType <: AbstractJSON
	"Free-text description of the constraint. In ECHO 10, this field is called RestrictionComment. Additional detailed instructions on how to access the granule data may be entered in this field."
	Description::Union{Nothing, String}
	"Numeric value that is used with Access Control Language (ACLs) to restrict access to this granule. For example, a provider might specify a granule level ACL that hides all granules with a value element set to 15. In ECHO, this field is called RestrictionFlag."
	Value::Float64
end
StructTypes.StructType(::Type{AccessConstraintsType}) = StructTypes.Struct()


"This entity stores orbital coverage information of the granule. This coverage is an alternative way of expressing granule spatial coverage. This information supports orbital backtrack searching on a granule."
struct OrbitType <: AbstractJSON
	"The latitude value of a spatially referenced point, in degrees. Latitude values range from -90 to 90."
	StartLatitude::Float64
	"Orbit start and end direction. A for ascending orbit and D for descending."
	EndDirection::String
	"The latitude value of a spatially referenced point, in degrees. Latitude values range from -90 to 90."
	EndLatitude::Float64
	"The longitude value of a spatially referenced point, in degrees. Longitude values range from -180 to 180."
	AscendingCrossing::Float64
	"Orbit start and end direction. A for ascending orbit and D for descending."
	StartDirection::String
end
StructTypes.StructType(::Type{OrbitType}) = StructTypes.Struct()


"This entity stores basic descriptive characteristics related to the Product Generation Executable associated with a granule."
struct PGEVersionClassType <: AbstractJSON
	"Version of the product generation executable that produced the granule."
	PGEVersion::String
	"Name of product generation executable."
	PGEName::Union{Nothing, String}
end
StructTypes.StructType(::Type{PGEVersionClassType}) = StructTypes.Struct()


"A reference to an additional attribute in the parent collection. The attribute reference may contain a granule specific value that will override the value in the parent collection for this granule. An attribute with the  same name must exist in the parent collection."
struct AdditionalAttributeType <: AbstractJSON
	"Values of the additional attribute."
	Values::Vector{String}
	"The additional attribute's name."
	Name::String
end
StructTypes.StructType(::Type{AdditionalAttributeType}) = StructTypes.Struct()


"Specifies the date and its type that the provider uses for the granule. For Create, Update, and Insert the date is the date that the granule file is created, updated, or inserted into the provider database by the provider. Delete is the date that the CMR should delete the granule metadata record from its repository."
struct ProviderDateType <: AbstractJSON
	"The types of dates that a metadata record can have."
	Type::String
	"This is the date that an event associated with the granule occurred."
	Date::String
end
StructTypes.StructType(::Type{ProviderDateType}) = StructTypes.Struct()


"This object requires any metadata record that is validated by this schema to provide information about the schema."
struct MetadataSpecificationType <: AbstractJSON
	"This element represents the URL where the schema lives. The schema can be downloaded."
	URL::String
	"This element represents the version of the schema."
	Version::String
	"This element represents the name of the schema."
	Name::String
end
StructTypes.StructType(::Type{MetadataSpecificationType}) = StructTypes.Struct()


"Information describing the scientific endeavor with which the granule is associated."
struct ProjectType <: AbstractJSON
	"The name of the campaign/experiment (e.g. Global climate observing system)."
	Campaigns::Union{Nothing, Vector{String}}
	"The unique identifier by which a project is known. The project is the scientific endeavor associated with the acquisition of the collection."
	ShortName::String
end
StructTypes.StructType(::Type{ProjectType}) = StructTypes.Struct()


"This entity holds the horizontal spatial coverage of a bounding box."
struct BoundingRectangleType <: AbstractJSON
	"The latitude value of a spatially referenced point, in degrees. Latitude values range from -90 to 90."
	NorthBoundingCoordinate::Float64
	"The longitude value of a spatially referenced point, in degrees. Longitude values range from -180 to 180."
	WestBoundingCoordinate::Float64
	"The longitude value of a spatially referenced point, in degrees. Longitude values range from -180 to 180."
	EastBoundingCoordinate::Float64
	"The latitude value of a spatially referenced point, in degrees. Latitude values range from -90 to 90."
	SouthBoundingCoordinate::Float64
end
StructTypes.StructType(::Type{BoundingRectangleType}) = StructTypes.Struct()


"Stores the data acquisition start and end date/time for a granule."
struct RangeDateTimeType <: AbstractJSON
	"The time when the temporal coverage period being described ended."
	EndingDateTime::Union{Nothing, String}
	"The time when the temporal coverage period being described began."
	BeginningDateTime::String
end
StructTypes.StructType(::Type{RangeDateTimeType}) = StructTypes.Struct()


"This entity is used to store the characteristics of the orbit calculated spatial domain to include the model name, orbit number, start and stop orbit number, equator crossing date and time, and equator crossing longitude."
struct OrbitCalculatedSpatialDomainType <: AbstractJSON
	"The reference to the orbital model to be used to calculate the geo-location of this data in order to determine global spatial extent."
	OrbitalModelName::Union{Nothing, String}
	"This attribute represents the date and time of the descending equator crossing."
	EquatorCrossingDateTime::Union{Nothing, String}
	"The orbit number to be used in calculating the spatial extent of this data."
	OrbitNumber::Union{Nothing, Int64}
	"Orbit number at the start of the data granule."
	BeginOrbitNumber::Union{Nothing, Int64}
	"Orbit number at the end of the data granule."
	EndOrbitNumber::Union{Nothing, Int64}
	"The longitude value of a spatially referenced point, in degrees. Longitude values range from -180 to 180."
	EquatorCrossingLongitude::Union{Nothing, Float64}
end
StructTypes.StructType(::Type{OrbitCalculatedSpatialDomainType}) = StructTypes.Struct()


"This element stores track information of the granule. Track information is used to allow a user to search for granules whose spatial extent is based on an orbital cycle, pass, and tile mapping. Though it is derived from the SWOT mission requirements, it is intended that this element type be generic enough so that other missions can make use of it. While track information is a type of spatial domain, it is expected that the metadata provider will provide geometry information that matches the spatial extent of the track information."
struct TrackType <: AbstractJSON
	"A pass number identifies a subset of a granule's spatial extent. This element holds a list of pass numbers and their tiles that exist in the granule. It will allow a user to search by pass number and its tiles that are contained with in a cycle number.  While trying to keep this generic for all to use, this comes from a SWOT requirement where a pass represents a 1/2 orbit. This element will then hold a list of 1/2 orbits and their tiles that together represent the granule's spatial extent."
	Passes::Vector{TrackPassTileType}
	"An integer that represents a specific set of orbital spatial extents defined by passes and tiles. Though intended to be generic, this comes from a SWOT mission requirement where each cycle represents a set of 1/2 orbits. Each 1/2 orbit is called a 'pass'. During science mode, a cycle represents 21 days of 14 full orbits or 588 passes."
	Cycle::Int64
end
StructTypes.StructType(::Type{TrackType}) = StructTypes.Struct()


"The longitude and latitude values of a spatially referenced point in degrees."
struct PointType <: AbstractJSON
	"The longitude value of a spatially referenced point, in degrees. Longitude values range from -180 to 180."
	Longitude::Float64
	"The latitude value of a spatially referenced point, in degrees. Latitude values range from -90 to 90."
	Latitude::Float64
end
StructTypes.StructType(::Type{PointType}) = StructTypes.Struct()


"The quality flags contain the science, operational and automatic quality flags which indicate the overall quality assurance levels of specific parameter values within a granule."
struct QAFlagsType <: AbstractJSON
	"The granule level flag applying generally to the granule and specifically to parameters the granule level. When applied to parameter, the flag refers to the quality of that parameter for the granule (as applicable). The parameters determining whether the flag is set are defined by the developer and documented in the Quality Flag Explanation."
	AutomaticQualityFlag::Union{Nothing, String}
	"A text explanation of the criteria used to set automatic quality flag; including thresholds or other criteria."
	AutomaticQualityFlagExplanation::Union{Nothing, String}
	"The granule level flag applying both generally to a granule and specifically to parameters at the granule level. When applied to parameter, the flag refers to the quality of that parameter for the granule (as applicable). The parameters determining whether the flag is set are defined by the developers and documented in the QualityFlagExplanation."
	OperationalQualityFlag::Union{Nothing, String}
	"Granule level flag applying to a granule, and specifically to parameters. When applied to parameter, the flag refers to the quality of that parameter for the granule (as applicable). The parameters determining whether the flag is set are defined by the developers and documented in the Quality Flag Explanation."
	ScienceQualityFlag::Union{Nothing, String}
	"A text explanation of the criteria used to set operational quality flag; including thresholds or other criteria."
	OperationalQualityFlagExplanation::Union{Nothing, String}
	"A text explanation of the criteria used to set science quality flag; including thresholds or other criteria."
	ScienceQualityFlagExplanation::Union{Nothing, String}
end
StructTypes.StructType(::Type{QAFlagsType}) = StructTypes.Struct()


"Defines the minimum and maximum value for one dimension of a two dimensional coordinate system."
struct TilingCoordinateType <: AbstractJSON
	MinimumValue::Float64
	MaximumValue::Union{Nothing, Float64}
end
StructTypes.StructType(::Type{TilingCoordinateType}) = StructTypes.Struct()


"This entity stores the tiling identification system for the granule. The tiling identification system information is an alternative way to express granule's spatial coverage based on a certain two dimensional coordinate system defined by the providers. The name must match the name in the parent collection."
struct TilingIdentificationSystemType <: AbstractJSON
	TilingIdentificationSystemName::String
	"Defines the minimum and maximum value for one dimension of a two dimensional coordinate system."
	Coordinate2::TilingCoordinateType
	"Defines the minimum and maximum value for one dimension of a two dimensional coordinate system."
	Coordinate1::TilingCoordinateType
end
StructTypes.StructType(::Type{TilingIdentificationSystemType}) = StructTypes.Struct()


"A reference to a collection metadata record's short name and version, or entry title to which this granule metadata record belongs."
struct CollectionReferenceType <: AbstractJSON
	"The collection's short name as per the UMM-C."
	ShortName::Union{Nothing, String}
	"The collections entry title as per the UMM-C."
	EntryTitle::Union{Nothing, String}
	"The collection's version as per the UMM-C."
	Version::Union{Nothing, String}
end
StructTypes.StructType(::Type{CollectionReferenceType}) = StructTypes.Struct()


"Allows the provider to provide a checksum value and checksum algorithm name to allow the user to calculate the checksum."
struct ChecksumType <: AbstractJSON
	"Describes the checksum value for a file."
	Value::String
	"The algorithm name by which the checksum was calulated. This allows the user to re-calculate the checksum to verify the integrity of the downloaded data."
	Algorithm::String
end
StructTypes.StructType(::Type{ChecksumType}) = StructTypes.Struct()


"This entity contains the type and value for the granule's vertical spatial domain."
struct VerticalSpatialDomainType <: AbstractJSON
	"Describes the unit of the vertical extent value."
	Unit::Union{Nothing, String}
	"Describes the extent of the area of vertical space covered by the granule. Use this for Atmosphere profiles or for a specific value."
	Value::Union{Nothing, String}
	"Describes the extent of the area of vertical space covered by the granule. Use this and MaximumValue to represent a range of values (Min and Max)."
	MinimumValue::Union{Nothing, String}
	"Describes the extent of the area of vertical space covered by the granule. Use this and MinimumValue to represent a range of values (Min and Max)."
	MaximumValue::Union{Nothing, String}
	"Describes the type of the area of vertical space covered by the granule locality."
	Type::Union{Nothing, String}
end
StructTypes.StructType(::Type{VerticalSpatialDomainType}) = StructTypes.Struct()


"This entity is used to reference characteristics defined in the parent collection."
struct CharacteristicType <: AbstractJSON
	"The value of the Characteristic attribute."
	Value::String
	"The name of the characteristic attribute."
	Name::String
end
StructTypes.StructType(::Type{CharacteristicType}) = StructTypes.Struct()


"A boundary is set of points connected by straight lines representing a polygon on the earth. It takes a minimum of three points to make a boundary. Points must be specified in counter-clockwise order and closed (the first and last vertices are the same)."
struct BoundaryType <: AbstractJSON
	Points::Vector{PointType}
end
StructTypes.StructType(::Type{BoundaryType}) = StructTypes.Struct()


"This entity stores an identifier. If the identifier is part of the enumeration then use it. If the enumeration is 'Other',  the provider must specify the identifier's name."
struct IdentifierType <: AbstractJSON
	"The identifier value."
	Identifier::Union{Nothing, String}
	"The Name of identifier."
	IdentifierName::Union{Nothing, String}
	"The enumeration of known identifier types."
	IdentifierType::Union{Nothing, String}
end
StructTypes.StructType(::Type{IdentifierType}) = StructTypes.Struct()


"Contains the excluded boundaries from the GPolygon."
struct ExclusiveZoneType <: AbstractJSON
	Boundaries::Vector{BoundaryType}
end
StructTypes.StructType(::Type{ExclusiveZoneType}) = StructTypes.Struct()


"The quality statistics element contains measures of quality for the granule. The parameters used to set these measures are not preset and will be determined by the data producer. Each set of measures can occur many times either for the granule as a whole or for individual parameters."
struct QAStatsType <: AbstractJSON
	"Granule level % missing data. This attribute can be repeated for individual parameters within a granule."
	QAPercentMissingData::Union{Nothing, Float64}
	"Granule level % out of bounds data. This attribute can be repeated for individual parameters within a granule."
	QAPercentOutOfBoundsData::Union{Nothing, Float64}
	"Granule level % interpolated data. This attribute can be repeated for individual parameters within a granule."
	QAPercentInterpolatedData::Union{Nothing, Float64}
	"This attribute is used to characterize the cloud cover amount of a granule. This attribute may be repeated for individual parameters within a granule. (Note - there may be more than one way to define a cloud or it's effects within a product containing several parameters; i.e. this attribute may be parameter specific)."
	QAPercentCloudCover::Union{Nothing, Float64}
end
StructTypes.StructType(::Type{QAStatsType}) = StructTypes.Struct()


"A reference to the device in the parent collection that was used to measure or record data, including direct human observation. In cases where instruments have a single composed of child instrument (sensor) or the instrument and composed of child instrument (sensor) are used synonymously (e.g. AVHRR) the both Instrument and composed of child instrument should be recorded. The child instrument information is represented by child entities. The instrument reference may contain granule specific characteristics and operation modes. These characteristics and modes are not checked against the referenced instrument."
struct InstrumentType <: AbstractJSON
	"References to instrument subcomponents in the parent collection's instrument used by various sources in the granule. An instrument subcomponent reference may contain characteristics specific to the granule."
	ComposedOf::Union{Nothing, Vector{InstrumentType}}
	"The unique name of the platform or instrument."
	ShortName::String
	"This entity identifies the instrument's operational modes for a specific collection associated with the channel, wavelength, and FOV (e.g., launch, survival, initialization, safe, diagnostic, standby, crosstrack, biaxial, solar calibration)."
	OperationalModes::Union{Nothing, Vector{String}}
	"This entity is used to define item additional attributes (unprocessed, custom data)."
	Characteristics::Union{Nothing, Vector{CharacteristicType}}
end
StructTypes.StructType(::Type{InstrumentType}) = StructTypes.Struct()


"A GPolygon specifies an area on the earth represented by a main boundary with optional boundaries for regions excluded from the main boundary."
struct GPolygonType <: AbstractJSON
	"Contains the excluded boundaries from the GPolygon."
	ExclusiveZone::Union{Nothing, ExclusiveZoneType}
	"A boundary is set of points connected by straight lines representing a polygon on the earth. It takes a minimum of three points to make a boundary. Points must be specified in counter-clockwise order and closed (the first and last vertices are the same)."
	Boundary::BoundaryType
end
StructTypes.StructType(::Type{GPolygonType}) = StructTypes.Struct()


"Information which describes the temporal extent of a specific granule."
struct TemporalExtentType <: AbstractJSON
	"Stores the data acquisition start and end date/time for a granule."
	RangeDateTime::Union{Nothing, RangeDateTimeType}
	"Stores the data acquisition date/time for a granule."
	SingleDateTime::Union{Nothing, String}
end
StructTypes.StructType(::Type{TemporalExtentType}) = StructTypes.Struct()


"This entity holds the horizontal spatial coverage of a line. A line area contains at lease two points."
struct LineType <: AbstractJSON
	Points::Vector{PointType}
end
StructTypes.StructType(::Type{LineType}) = StructTypes.Struct()


"This entity holds the geometry representing the spatial coverage information of a granule."
struct GeometryType <: AbstractJSON
	"This entity holds the horizontal spatial coverage of a bounding box."
	BoundingRectangles::Union{Nothing, Vector{BoundingRectangleType}}
	"A GPolygon specifies an area on the earth represented by a main boundary with optional boundaries for regions excluded from the main boundary."
	GPolygons::Union{Nothing, Vector{GPolygonType}}
	"The horizontal spatial coverage of a point."
	Points::Union{Nothing, Vector{PointType}}
	"This entity holds the horizontal spatial coverage of a line. A line area contains at least two points."
	Lines::Union{Nothing, Vector{LineType}}
end
StructTypes.StructType(::Type{GeometryType}) = StructTypes.Struct()


"This set of elements describes a file. The file can be a part of the entire granule or is the granule."
struct FileType <: AbstractJSON
	"The format that granule data confirms to. While the value is listed as open to any text, CMR requires that it confirm to one of the values on the GranuleDataFormat values in the Keyword Management System: https://gcmd.earthdata.nasa.gov/kms/concepts/concept_scheme/GranuleDataFormat"
	Format::Union{Nothing, String}
	"The size in Bytes of the volume of data contained in the granule. Bytes are defined as eight bits. Please use this element instead of or inclusive with the Size element. The issue with the size element is that if CMR data providers use a unit other than Bytes, end users don't know how the granule size was calculated. For example, if the unit was MegaBytes, the size could be calculated by using 1000xE2 Bytes (MegaBytes) or 1024xE2 Bytes (mebibytes) and therefore there is no systematic way to know the actual size of a granule by using the granule metadata record."
	SizeInBytes::Union{Nothing, Int64}
	"The mime type of the resource."
	MimeType::Union{Nothing, String}
	"The unit of the file size."
	SizeUnit::Union{Nothing, String}
	"Allows the provider to state whether the distributable item's format is its native format or another supported format."
	FormatType::Union{Nothing, String}
	"Allows the provider to provide a checksum value and checksum algorithm name to allow the user to calculate the checksum."
	Checksum::Union{Nothing, ChecksumType}
	"This field describes the name of the actual file."
	Name::String
	"The size of the volume of data contained in the granule. Please use the SizeInBytes element either instead of this one or inclusive of this one. The issue with the size element is that if CMR data providers use a unit other than Bytes, end users don't know how the granule size was calculated. For example, if the unit was MegaBytes, the size could be calculated by using 1000xE2 Bytes (MegaBytes) or 1024xE2 Bytes (mebibytes) and therefore there is no systematic way to know the actual size of a granule by using the granule metadata record."
	Size::Union{Nothing, Float64}
end
StructTypes.StructType(::Type{FileType}) = StructTypes.Struct()


"This entity contains the name of the geophysical parameter expressed in the data as well as associated quality flags and quality statistics. The quality statistics element contains measures of quality for the granule. The parameters used to set these measures are not preset and will be determined by the data producer. Each set of measures can occur many times either for the granule as a whole or for individual parameters. The quality flags contain the science, operational and automatic quality flags which indicate the overall quality assurance levels of specific parameter values within a granule."
struct MeasuredParameterType <: AbstractJSON
	"The quality statistics element contains measures of quality for the granule. The parameters used to set these measures are not preset and will be determined by the data producer. Each set of measures can occur many times either for the granule as a whole or for individual parameters."
	QAStats::Union{Nothing, QAStatsType}
	"The quality flags contain the science, operational and automatic quality flags which indicate the overall quality assurance levels of specific parameter values within a granule."
	QAFlags::Union{Nothing, QAFlagsType}
	"The measured science parameter expressed in the data granule."
	ParameterName::String
end
StructTypes.StructType(::Type{MeasuredParameterType}) = StructTypes.Struct()


"A reference to a platform in the parent collection that is associated with the acquisition of the granule. The platform must exist in the parent collection. For example, Platform types may include (but are not limited to): ADEOS-II, AEM-2, Terra, Aqua, Aura, BALLOONS, BUOYS, C-130, DEM, DMSP-F1,etc."
struct PlatformType <: AbstractJSON
	"The unique name of the platform or instrument."
	ShortName::String
	"References to the devices in the parent collection that were used to measure or record data, including direct human observation."
	Instruments::Union{Nothing, Vector{InstrumentType}}
end
StructTypes.StructType(::Type{PlatformType}) = StructTypes.Struct()


"Information about a granule with horizontal spatial coverage."
struct HorizontalSpatialDomainType <: AbstractJSON
	"The appropriate numeric or alpha code used to identify the various zones in the granule's grid coordinate system."
	ZoneIdentifier::Union{Nothing, String}
	"This entity stores orbital coverage information of the granule. This coverage is an alternative way of expressing granule spatial coverage. This information supports orbital backtrack searching on a granule."
	Orbit::Union{Nothing, OrbitType}
	"This element stores track information of the granule. Track information is used to allow a user to search for granules whose spatial extent is based on an orbital cycle, pass, and tile mapping. Though it is derived from the SWOT mission requirements, it is intended that this element type be generic enough so that other missions can make use of it. While track information is a type of spatial domain, it is expected that the metadata provider will provide geometry information that matches the spatial extent of the track information."
	Track::Union{Nothing, TrackType}
	"This entity holds the geometry representing the spatial coverage information of a granule."
	Geometry::Union{Nothing, GeometryType}
end
StructTypes.StructType(::Type{HorizontalSpatialDomainType}) = StructTypes.Struct()


"This class contains attributes which describe the spatial extent of a granule. Spatial Extent includes any or all of Granule Localities, Horizontal Spatial Domain, and Vertical Spatial Domain."
struct SpatialExtentType <: AbstractJSON
	"Information about a granule with horizontal spatial coverage."
	HorizontalSpatialDomain::Union{Nothing, HorizontalSpatialDomainType}
	"This entity stores information used at the granule level to describe the labeling of granules with compounded time/space text values and which are subsequently used to define more phenomenological-based granules, thus the locality type and description are contained."
	GranuleLocalities::Union{Nothing, Vector{String}}
	"This represents the domain value and type for the granule's vertical spatial domain."
	VerticalSpatialDomains::Union{Nothing, Vector{VerticalSpatialDomainType}}
end
StructTypes.StructType(::Type{SpatialExtentType}) = StructTypes.Struct()


"This set of elements describes a file package or a file that contains other files.  Normally this is either a tar or a zip file."
struct FilePackageType <: AbstractJSON
	"The format that granule data confirms to. While the value is listed as open to any text, CMR requires that it confirm to one of the values on the GranuleDataFormat values in the Keyword Management System: https://gcmd.earthdata.nasa.gov/kms/concepts/concept_scheme/GranuleDataFormat"
	Format::Union{Nothing, String}
	"Allows the provider to add the list of the files that are included in this one."
	Files::Union{Nothing, Vector{FileType}}
	"The size in Bytes of the volume of data contained in the granule. Bytes are defined as eight bits. Please use this element instead of or inclusive with the Size element. The issue with the size element is that if CMR data providers use a unit other than Bytes, end users don't know how the granule size was calculated. For example, if the unit was MegaBytes, the size could be calculated by using 1000xE2 Bytes (MegaBytes) or 1024xE2 Bytes (mebibytes) and therefore there is no systematic way to know the actual size of a granule by using the granule metadata record."
	SizeInBytes::Union{Nothing, Int64}
	"The mime type of the resource."
	MimeType::Union{Nothing, String}
	"The unit of the file size."
	SizeUnit::Union{Nothing, String}
	"Allows the provider to provide a checksum value and checksum algorithm name to allow the user to calculate the checksum."
	Checksum::Union{Nothing, ChecksumType}
	"This field describes the name of the actual file."
	Name::String
	"The size of the volume of data contained in the granule. Please use the SizeInBytes element either instead of this one or inclusive of this one. The issue with the size element is that if CMR data providers use a unit other than Bytes, end users don't know how the granule size was calculated. For example, if the unit was MegaBytes, the size could be calculated by using 1000xE2 Bytes (MegaBytes) or 1024xE2 Bytes (mebibytes) and therefore there is no systematic way to know the actual size of a granule by using the granule metadata record."
	Size::Union{Nothing, Float64}
end
StructTypes.StructType(::Type{FilePackageType}) = StructTypes.Struct()


"This entity stores the basic descriptive characteristics associated with a granule."
struct DataGranuleType <: AbstractJSON
	"A list of the file(s) or file package(s) that make up the granule. A file package is something like a tar or zip file."
	ArchiveAndDistributionInformation::Union{Nothing, Vector{Union{FilePackageType,FileType}}}
	"This holds any granule identifiers the provider wishes to provide."
	Identifiers::Union{Nothing, Vector{IdentifierType}}
	"This attribute is used to identify if a granule was collected during the day, night (between  sunset and sunrise) or both."
	DayNightFlag::String
	"The date and time a specific granule was produced by a PGE."
	ProductionDateTime::String
	"Granule level, stating what reprocessing may be performed on this granule."
	ReprocessingPlanned::Union{Nothing, String}
	"Granule level, stating what reprocessing has been performed on this granule."
	ReprocessingActual::Union{Nothing, String}
end
StructTypes.StructType(::Type{DataGranuleType}) = StructTypes.Struct()


struct UMM_G <: AbstractJSON
"Information which describes the temporal extent of a specific granule."
	TemporalExtent::Union{Nothing, TemporalExtentType}
"A reference to a collection metadata record's short name and version, or entry title to which this granule metadata record belongs."
	CollectionReference::CollectionReferenceType
"This entity stores the tiling identification system for the granule. The tiling identification system information is an alternative way to express granule's spatial coverage based on a certain two dimensional coordinate system defined by the providers. The name must match the name in the parent collection."
	TilingIdentificationSystem::Union{Nothing, TilingIdentificationSystemType}
"This element describes any data/service related URLs that include project home pages, services, related data archives/servers, metadata extensions, direct links to online software packages, web mapping services, links to images, or other data."
	RelatedUrls::Union{Nothing, Vector{RelatedUrlType}}
"The Universal Reference ID of the granule referred by the data provider. This ID is unique per data provider."
	GranuleUR::String
"Represents the native grid mapping of the granule, if the granule is gridded."
	GridMappingNames::Union{Nothing, Vector{String}}
"A reference to a platform in the parent collection that is associated with the acquisition of the granule. The platform must exist in the parent collection. For example, Platform types may include (but are not limited to): ADEOS-II, AEM-2, Terra, Aqua, Aura, BALLOONS, BUOYS, C-130, DEM, DMSP-F1,etc."
	Platforms::Union{Nothing, Vector{PlatformType}}
"This entity stores the basic descriptive characteristics associated with a granule."
	DataGranule::Union{Nothing, DataGranuleType}
"Represents the native projection of the granule if the granule has a native projection."
	NativeProjectionNames::Union{Nothing, Vector{String}}
"A percentage value indicating how much of the area of a granule (the EOSDIS data unit) has been obscured by clouds. It is worth noting that there are many different measures of cloud cover within the EOSDIS data holdings and that the cloud cover parameter that is represented in the archive is dataset-specific."
	CloudCover::Union{Nothing, Float64}
"This object requires any metadata record that is validated by this schema to provide information about the schema."
	MetadataSpecification::MetadataSpecificationType
"Information about any physical constraints for accessing the data set."
	AccessConstraints::Union{Nothing, AccessConstraintsType}
"This entity stores basic descriptive characteristics related to the Product Generation Executable associated with a granule."
	PGEVersionClass::Union{Nothing, PGEVersionClassType}
"The name of the scientific program, field campaign, or project from which the data were collected. This element is intended for the non-space assets such as aircraft, ground systems, balloons, sondes, ships, etc. associated with campaigns. This element may also cover a long term project that continuously creates new data sets — like MEaSUREs from ISCCP and NVAP or CMARES from MISR. Project also includes the Campaign sub-element to support multiple campaigns under the same project."
	Projects::Union{Nothing, Vector{ProjectType}}
"Reference to an additional attribute in the parent collection. The attribute reference may contain a granule specific value that will override the value in the parent collection for this granule. An attribute with the same name must exist in the parent collection."
	AdditionalAttributes::Union{Nothing, Vector{AdditionalAttributeType}}
"This entity contains the identification of the input granule(s) for a specific granule."
	InputGranules::Union{Nothing, Vector{String}}
"Dates related to activities involving the the granule and the data provider database with the exception for Delete. For Create, Update, and Insert the date is the date that the granule file is created, updated, or inserted into the provider database by the provider. Delete is the date that the CMR should delete the granule metadata record from its repository."
	ProviderDates::Vector{ProviderDateType}
"This class contains attributes which describe the spatial extent of a granule. Spatial Extent includes any or all of Granule Localities, Horizontal Spatial Domain, and Vertical Spatial Domain."
	SpatialExtent::Union{Nothing, SpatialExtentType}
"This entity is used to store the characteristics of the orbit calculated spatial domain to include the model name, orbit number, start and stop orbit number, equator crossing date and time, and equator crossing longitude."
	OrbitCalculatedSpatialDomains::Union{Nothing, Vector{OrbitCalculatedSpatialDomainType}}
"This entity contains the name of the geophysical parameter expressed in the data as well as associated quality flags and quality statistics. The quality statistics element contains measures of quality for the granule. The parameters used to set these measures are not preset and will be determined by the data producer. Each set of measures can occur many times either for the granule as a whole or for individual parameters. The quality flags contain the science, operational and automatic quality flags which indicate the overall quality assurance levels of specific parameter values within a granule."
	MeasuredParameters::Union{Nothing, Vector{MeasuredParameterType}}
end
StructTypes.StructType(::Type{UMM_G}) = StructTypes.Struct()


