# This file is generated from gen/codegen.jl. Do not edit directly.
module Collections
using StructTypes
using ..EarthData: AbstractJSON

"Information about any constraints for accessing the data set. This includes any special restrictions, legal prerequisites, limitations and/or warnings on obtaining the data set."
struct AccessConstraintsType <: AbstractJSON
    "Free-text description of the constraint.  In DIF, this field is called Access_Constraint.   In ECHO, this field is called RestrictionComment.  Examples of text in this field are Public, In-house, Limited.  Additional detailed instructions on how to access the collection data may be entered in this field."
    Description::String
    "Numeric value that is used with Access Control Language (ACLs) to restrict access to this collection.  For example, a provider might specify a collection level ACL that hides all collections with a value element set to 15.   In ECHO, this field is called RestrictionFlag.  This field does not exist in DIF."
    Value::Union{Nothing,Float64}
end
StructTypes.StructType(::Type{AccessConstraintsType}) = StructTypes.Struct()


"Gridded Range Resolutions object describes range resolution data for gridded data products."
struct HorizontalDataResolutionGriddedRangeType <: AbstractJSON
    "Units of measure used for the geodetic latitude and longitude resolution values (e.g., decimal degrees)."
    Unit::Union{Nothing,String}
    "The minimum, minimum difference between two adjacent values on a horizontal plane in the X axis. In most cases this is along the longitudinal axis."
    MinimumXDimension::Union{Nothing,Float64}
    "The maximum, minimum difference between two adjacent values on a horizontal plane in the X axis. In most cases this is along the longitudinal axis."
    MaximumXDimension::Union{Nothing,Float64}
    "The minimum, minimum difference between two adjacent values on a horizontal plan in the Y axis. In most cases this is along the latitudinal axis."
    MinimumYDimension::Union{Nothing,Float64}
    "The maximum, minimum difference between two adjacent values on a horizontal plan in the Y axis. In most cases this is along the latitudinal axis."
    MaximumYDimension::Union{Nothing,Float64}
end
StructTypes.StructType(::Type{HorizontalDataResolutionGriddedRangeType}) =
    StructTypes.Struct()


"Additional unique attributes of the collection, beyond those defined in the UMM model, which the data provider deems useful for end-user understanding of the data in the collection.  Additional attributes are also called Product Specific Attributes (PSAs) or non-core attributes.  Examples are HORIZONTALTILENUMBER, VERTICALTILENUMBER."
struct AdditionalAttributeType <: AbstractJSON
    "The maximum value of the additional attribute over the whole collection."
    ParameterRangeEnd::Union{Nothing,String}
    "Identifies a namespace for the additional attribute name."
    Group::Union{Nothing,String}
    "The standard unit of measurement for the additional attribute.  For example, meters, hertz."
    ParameterUnitsOfMeasure::Union{Nothing,String}
    "The smallest unit increment to which the additional attribute value is measured."
    MeasurementResolution::Union{Nothing,String}
    "An estimate of the accuracy of the values of the additional attribute. For example, for AVHRR: Measurement error or precision-measurement error or precision of a data product parameter. This can be specified in percent or the unit with which the parameter is measured."
    ParameterValueAccuracy::Union{Nothing,String}
    "This entity contains the additional attribute data types."
    DataType::String
    "The minimum value of the additional attribute over the whole collection."
    ParameterRangeBegin::Union{Nothing,String}
    "Describes the method used for determining the parameter value accuracy that is given for this additional attribute."
    ValueAccuracyExplanation::Union{Nothing,String}
    "The name (1 word description) of the additional attribute."
    Name::String
    "Value of the additional attribute if it is the same for all granules across the collection.  If the value of the additional attribute may differ by granule, leave this collection-level value blank."
    Value::Union{Nothing,String}
    "Free-text description of the additional attribute."
    Description::String
    "The date this additional attribute information was updated."
    UpdateDate::Union{Nothing,String}
end
StructTypes.StructType(::Type{AdditionalAttributeType}) = StructTypes.Struct()


"This element describes the geodetic model for the data product."
struct GeodeticModelType <: AbstractJSON
    "The ratio of the Earth's major axis to the difference between the major and the minor."
    DenominatorOfFlatteningRatio::Union{Nothing,Float64}
    "Radius of the equatorial axis of the ellipsoid."
    SemiMajorAxis::Union{Nothing,Float64}
    "Identification given to established representation of the Earth's shape."
    EllipsoidName::Union{Nothing,String}
    "The identification given to the level surface taken as the surface of reference from which measurements are compared."
    HorizontalDatumName::Union{Nothing,String}
end
StructTypes.StructType(::Type{GeodeticModelType}) = StructTypes.Struct()


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


"This sub-element either contains a license summary or free-text description that details the permitted use or limitation of this collection."
struct UseConstraintsDescriptionType <: AbstractJSON
    "This sub-element either contains a license summary or free-text description that details the permitted use or limitation of this collection."
    Description::Union{Nothing,String}
end
StructTypes.StructType(::Type{UseConstraintsDescriptionType}) = StructTypes.Struct()


struct DoiType <: AbstractJSON
    "This element stores the fact that a DOI (Digital Object Identifier) is not applicable or is unknown for this record."
    MissingReason::Union{Nothing,String}
    "This element stores the DOI (Digital Object Identifier) that identifies the collection.  Note: The values should start with the directory indicator which in ESDIS' case is 10.  If the DOI was registered through ESDIS, the beginning of the string should be 10.5067. The DOI URL is not stored here; it should be stored as a RelatedURL."
    DOI::Union{Nothing,String}
    "The Authority (who created it or owns it) of a unique identifier."
    Authority::Union{Nothing,String}
    "This element describes the reason the DOI is not applicable or unknown."
    Explanation::Union{Nothing,String}
end
StructTypes.StructType(::Type{DoiType}) = StructTypes.Struct()


"Represents the information needed for a DistributionURL where data is retrieved."
struct GetDataType <: AbstractJSON
    "The format of the data.  The controlled vocabulary for formats is maintained in the Keyword Management System (KMS)"
    Format::String
    "Unit of information, together with Size determines total size in bytes of the data."
    Unit::String
    "The fee for ordering the collection data.  The fee is entered as a number, in US Dollars."
    Fees::Union{Nothing,String}
    "The mime type of the service."
    MimeType::Union{Nothing,String}
    "The checksum, usually a SHA1 or md5 checksum for the data file."
    Checksum::Union{Nothing,String}
    "The size of the data."
    Size::Float64
end
StructTypes.StructType(::Type{GetDataType}) = StructTypes.Struct()


"Generic Resolutions object describes general resolution data for a data product where it is not known if a data product is gridded or not."
struct HorizontalDataGenericResolutionType <: AbstractJSON
    "The minimum difference between two adjacent values on a horizontal plan in the Y axis. In most cases this is along the latitudinal axis."
    YDimension::Union{Nothing,Float64}
    "Units of measure used for the geodetic latitude and longitude resolution values (e.g., decimal degrees)."
    Unit::Union{Nothing,String}
    "The minimum difference between two adjacent values on a horizontal plane in the X axis. In most cases this is along the longitudinal axis."
    XDimension::Union{Nothing,Float64}
end
StructTypes.StructType(::Type{HorizontalDataGenericResolutionType}) = StructTypes.Struct()


struct VerticalSpatialDomainType <: AbstractJSON
    "Describes the extent of the area of vertical space covered by the collection. Must be accompanied by an Altitude Encoding Method description. The datatype for this attribute is the value of the attribute VerticalSpatialDomainType. The unit for this attribute is the value of either DepthDistanceUnits or AltitudeDistanceUnits."
    Value::String
    "Describes the type of the area of vertical space covered by the collection locality."
    Type::String
end
StructTypes.StructType(::Type{VerticalSpatialDomainType}) = StructTypes.Struct()


"Information about Periodic Date Time collections, including the name of the temporal period in addition to the start and end dates, duration unit and value, and cycle duration unit and value."
struct PeriodicDateTimeType <: AbstractJSON
    "The date (day and time) of the end occurrence of this regularly occurring period which is relevant to the collection coverage."
    EndDate::String
    "The unit specification of the period cycle duration."
    PeriodCycleDurationUnit::String
    "The date (day and time) of the first occurrence of this regularly occurring period which is relevant to the collection coverage."
    StartDate::String
    PeriodCycleDurationValue::Int64
    "The name given to the recurring time period. e.g. 'spring - north hemi.'"
    Name::String
    "The unit specification for the period duration."
    DurationUnit::String
    "The number of PeriodDurationUnits in the RegularPeriodic period. e.g. the RegularPeriodic event 'Spring-North Hemi' might have a PeriodDurationUnit='MONTH' PeriodDurationValue='3' PeriodCycleDurationUnit='YEAR' PeriodCycleDurationValue='1' indicating that Spring-North Hemi lasts for 3 months and has a cycle duration of 1 year. The unit for the attribute is the value of the attribute PeriodDurationValue."
    DurationValue::Int64
end
StructTypes.StructType(::Type{PeriodicDateTimeType}) = StructTypes.Struct()


"This entity contains the physical address details for the contact."
struct AddressType <: AbstractJSON
    "An address line for the street address, used for mailing or physical addresses of organizations or individuals who serve as contacts for the collection."
    StreetAddresses::Union{Nothing,Vector{String}}
    "The city portion of the physical address."
    City::Union{Nothing,String}
    "The zip or other postal code portion of the physical address."
    PostalCode::Union{Nothing,String}
    "The country of the physical address."
    Country::Union{Nothing,String}
    "The state or province portion of the physical address."
    StateProvince::Union{Nothing,String}
end
StructTypes.StructType(::Type{AddressType}) = StructTypes.Struct()


"The largest width of an instrument's footprint as measured on the Earths surface. The largest Footprint takes the place of SwathWidth in the Orbit Backtrack Algorithm if SwathWidth does not exist. The optional description element allows the user of the record to be able to distinguish between the different footprints of an instrument if it has more than 1."
struct FootprintType <: AbstractJSON
    "The description element allows the user of the record to be able to distinguish between the different footprints of an instrument if it has more than 1."
    Description::Union{Nothing,String}
    "The largest width of an instrument's footprint as measured on the Earths surface. The largest Footprint takes the place of SwathWidth in the Orbit Backtrack Algorithm if SwathWidth does not exist."
    Footprint::Float64
    "The Footprint value's unit."
    FootprintUnit::String
end
StructTypes.StructType(::Type{FootprintType}) = StructTypes.Struct()


struct ChronostratigraphicUnitType <: AbstractJSON
    Period::Union{Nothing,String}
    Epoch::Union{Nothing,String}
    Eon::String
    Era::Union{Nothing,String}
    Stage::Union{Nothing,String}
    DetailedClassification::Union{Nothing,String}
end
StructTypes.StructType(::Type{ChronostratigraphicUnitType}) = StructTypes.Struct()


"This element contains the Processing Level Id and the Processing Level Description"
struct ProcessingLevelType <: AbstractJSON
    "An identifier indicating the level at which the data in the collection are processed, ranging from Level0 (raw instrument data at full resolution) to Level4 (model output or analysis results).  The value of Processing Level Id is chosen from a controlled vocabulary."
    Id::String
    "Description of the meaning of the Processing Level Id, e.g., the Description for the Level4 Processing Level Id might be 'Model output or results from analyses of lower level data'"
    ProcessingLevelDescription::Union{Nothing,String}
end
StructTypes.StructType(::Type{ProcessingLevelType}) = StructTypes.Struct()


"Describes the online resource pertaining to the data."
struct OnlineResourceType <: AbstractJSON
    "The URL of the website related to the online resource."
    Linkage::String
    "The description of the online resource."
    Description::Union{Nothing,String}
    "The application profile holds the name of the application that can service the data. For example if the URL points to a word document, then the applicationProfile is MS-Word."
    ApplicationProfile::Union{Nothing,String}
    "The mime type of the online resource."
    MimeType::Union{Nothing,String}
    "The protocol of the linkage for the online resource, such as https, svn, ftp, etc."
    Protocol::Union{Nothing,String}
    "The name of the online resource."
    Name::Union{Nothing,String}
    "The function of the online resource. In ISO where this class originated the valid values are: download, information, offlineAccess, order, and search."
    Function::Union{Nothing,String}
end
StructTypes.StructType(::Type{OnlineResourceType}) = StructTypes.Struct()


"Specifies the date and its type."
struct DateType <: AbstractJSON
    "The name of supported lineage date types"
    Type::String
    "This is the date that an event associated with the collection or its metadata occurred."
    Date::Union{Nothing,String}
end
StructTypes.StructType(::Type{DateType}) = StructTypes.Struct()


"Represents a Service through a URL where the service will act on data and return the result to the caller."
struct GetServiceType <: AbstractJSON
    "The data type of the data provided by the service."
    DataType::String
    "The format of the data."
    Format::Union{Nothing,String}
    "The mime type of the service."
    MimeType::String
    "The URI of the data provided by the service."
    URI::Union{Nothing,Vector{String}}
    "The full name of the service."
    FullName::String
    "The data identifier of the data provided by the service. Typically, this is a file name."
    DataID::String
    "The protocol of the service."
    Protocol::String
end
StructTypes.StructType(::Type{GetServiceType}) = StructTypes.Struct()


"Orbit parameters for the collection used by the Orbital Backtrack Algorithm."
struct OrbitParametersType <: AbstractJSON
    "Total observable width of the satellite sensor nominally measured at the equator."
    SwathWidth::Union{Nothing,Float64}
    "The InclinationAngle value's unit."
    InclinationAngleUnit::String
    "The latitude start of the orbit relative to the equator. This is used by the backtrack search algorithm to treat the orbit as if it starts from the specified latitude. This is optional and will default to 0 if not specified."
    StartCircularLatitude::Union{Nothing,Float64}
    "The StartCircularLatitude value's unit."
    StartCircularLatitudeUnit::Union{Nothing,String}
    "A list of instrument footprints or field of views. A footprint holds the largest width of the described footprint as measured on the earths surface along with the width's unit. An optional description element exists to be able to distinguish between the footprints, if that is desired. This element is optional. If this element is used at least 1 footprint must exist in the list."
    Footprints::Union{Nothing,Vector{FootprintType}}
    "The SwathWidth value's unit."
    SwathWidthUnit::Union{Nothing,String}
    "The time in decimal minutes the satellite takes to make one full orbit."
    OrbitPeriod::Float64
    "The number of full orbits composing each granule. This may be a fraction of an orbit."
    NumberOfOrbits::Float64
    "The Orbit Period value's unit."
    OrbitPeriodUnit::String
    "The heading of the satellite as it crosses the equator on the ascending pass. This is the same as (180-declination) and also the same as the highest latitude achieved by the satellite."
    InclinationAngle::Float64
end
StructTypes.StructType(::Type{OrbitParametersType}) = StructTypes.Struct()


"The reference frame or system from which depth is measured. The information contains the datum name, distance units and encoding method, which provide the definition for the system."
struct DepthSystemDefinitionType <: AbstractJSON
    "The identification given to the level surface taken as the surface of reference from which measurements are compared."
    DatumName::Union{Nothing,String}
    "The units in which depth measurements are recorded."
    DistanceUnits::Union{Nothing,String}
    "The minimum distance possible between two adjacent values, expressed in distance units of measure for the collection."
    Resolutions::Union{Nothing,Vector{Float64}}
end
StructTypes.StructType(::Type{DepthSystemDefinitionType}) = StructTypes.Struct()


"Enables specification of Earth science keywords related to the collection.  The controlled vocabulary for Science Keywords is maintained in the Keyword Management System (KMS)."
struct ScienceKeywordType <: AbstractJSON
    DetailedVariable::Union{Nothing,String}
    Term::String
    Topic::String
    VariableLevel1::Union{Nothing,String}
    VariableLevel3::Union{Nothing,String}
    Category::String
    VariableLevel2::Union{Nothing,String}
end
StructTypes.StructType(::Type{ScienceKeywordType}) = StructTypes.Struct()


"Gridded Resolutions object describes resolution data for gridded data products."
struct HorizontalDataResolutionGriddedType <: AbstractJSON
    "The minimum difference between two adjacent values on a horizontal plan in the Y axis. In most cases this is along the latitudinal axis."
    YDimension::Union{Nothing,Float64}
    "Units of measure used for the geodetic latitude and longitude resolution values (e.g., decimal degrees)."
    Unit::Union{Nothing,String}
    "The minimum difference between two adjacent values on a horizontal plane in the X axis. In most cases this is along the longitudinal axis."
    XDimension::Union{Nothing,Float64}
end
StructTypes.StructType(::Type{HorizontalDataResolutionGriddedType}) = StructTypes.Struct()


struct BoundingRectangleType <: AbstractJSON
    "The latitude value of a spatially referenced point, in degrees.  Latitude values range from -90 to 90."
    NorthBoundingCoordinate::Float64
    "The longitude value of a spatially referenced point, in degrees.  Longitude values range from -180 to 180."
    WestBoundingCoordinate::Float64
    "The longitude value of a spatially referenced point, in degrees.  Longitude values range from -180 to 180."
    EastBoundingCoordinate::Float64
    "The latitude value of a spatially referenced point, in degrees.  Latitude values range from -90 to 90."
    SouthBoundingCoordinate::Float64
end
StructTypes.StructType(::Type{BoundingRectangleType}) = StructTypes.Struct()


"Non Gridded Resolutions object describes resolution data for non gridded data products."
struct HorizontalDataResolutionNonGriddedType <: AbstractJSON
    "The minimum difference between two adjacent values on a horizontal plan in the Y axis. In most cases this is along the latitudinal axis."
    YDimension::Union{Nothing,Float64}
    "Units of measure used for the geodetic latitude and longitude resolution values (e.g., decimal degrees)."
    Unit::Union{Nothing,String}
    "This element describes the instrument scanning direction."
    ScanDirection::Union{Nothing,String}
    "This element describes the angle of the measurement with respect to the instrument that give an understanding of the specified resolution."
    ViewingAngleType::Union{Nothing,String}
    "The minimum difference between two adjacent values on a horizontal plane in the X axis. In most cases this is along the longitudinal axis."
    XDimension::Union{Nothing,Float64}
end
StructTypes.StructType(::Type{HorizontalDataResolutionNonGriddedType}) =
    StructTypes.Struct()


struct LocalCoordinateSystemType <: AbstractJSON
    "A description of the Local Coordinate System and geo-reference information."
    Description::Union{Nothing,String}
    "The information provided to register the local system to the Earth (e.g. control points, satellite ephemeral data, and inertial navigation data)."
    GeoReferenceInformation::Union{Nothing,String}
end
StructTypes.StructType(::Type{LocalCoordinateSystemType}) = StructTypes.Struct()


"This element defines how the data may or may not be used after access is granted to assure the protection of privacy or intellectual property. This includes license text, license URL, or any special restrictions, legal prerequisites, terms and conditions, and/or limitations on using the data set. Data providers may request acknowledgement of the data from users and claim no responsibility for quality and completeness of data."
struct UseConstraintsType <: AbstractJSON
    "Describes the online resource pertaining to the data."
    LicenseURL::Union{Nothing,OnlineResourceType}
    "This sub-element if true, describes to end users and machines that this collection's data is free of charge and open for any use the user sees fit."
    FreeAndOpenData::Union{Nothing,Bool}
    "This sub-element either contains a license summary or free-text description that details the permitted use or limitation of this collection."
    Description::Union{Nothing,String}
    "This element holds the actual license text. If this element is used the LicenseUrl element cannot be used."
    LicenseText::Union{Nothing,String}
end
StructTypes.StructType(::Type{UseConstraintsType}) = StructTypes.Struct()


"This element defines a hierarchical location list. It replaces SpatialKeywords. The controlled vocabulary for location keywords is maintained in the Keyword Management System (KMS). Each tier must have data in the tier above it."
struct LocationKeywordType <: AbstractJSON
    "Fifth-tier controlled keyword hierarchical level that contains the regional sub-location where the collection data was taken from"
    Subregion3::Union{Nothing,String}
    "Top-level controlled keyword hierarchical level that contains the largest general location where the collection data was taken from."
    Category::String
    "Second-tier controlled keyword hierarchical level that contains the regional location where the collection data was taken from"
    Type::Union{Nothing,String}
    "Fourth-tier controlled keyword hierarchical level that contains the regional sub-location where the collection data was taken from"
    Subregion2::Union{Nothing,String}
    "Third-tier controlled keyword hierarchical level that contains the regional sub-location where the collection data was taken from"
    Subregion1::Union{Nothing,String}
    "Uncontrolled keyword hierarchical level that contains the specific location where the collection data was taken from. Exists outside the hierarchy."
    DetailedLocation::Union{Nothing,String}
end
StructTypes.StructType(::Type{LocationKeywordType}) = StructTypes.Struct()


"Method for contacting the data contact. A contact can be available via phone, email, Facebook, or Twitter."
struct ContactMechanismType <: AbstractJSON
    "This is the contact phone number, email address, Facebook address, or Twitter handle associated with the contact method."
    Value::String
    "Defines the possible contact mechanism types."
    Type::String
end
StructTypes.StructType(::Type{ContactMechanismType}) = StructTypes.Struct()


"The longitude and latitude values of a spatially referenced point in degrees."
struct PointType <: AbstractJSON
    "The longitude value of a spatially referenced point, in degrees.  Longitude values range from -180 to 180."
    Longitude::Float64
    "The latitude value of a spatially referenced point, in degrees.  Latitude values range from -90 to 90."
    Latitude::Float64
end
StructTypes.StructType(::Type{PointType}) = StructTypes.Struct()


"This element allows end users to get direct access to data products that are stored in the Amazon Web Service (AWS) S3 buckets. The sub elements include S3 credentials end point and a documentation URL as well as bucket prefix names and an AWS region."
struct DirectDistributionInformationType <: AbstractJSON
    "Defines the possible values for the Amazon Web Service US S3 bucket and/or object prefix names."
    S3BucketAndObjectPrefixNames::Union{Nothing,Vector{String}}
    "Defines the URL where the credential documentation are stored."
    S3CredentialsAPIDocumentationURL::String
    "Defines the URL where the credentials are stored."
    S3CredentialsAPIEndpoint::String
    "Defines the possible values for the Amazon Web Service US Regions where the data product resides."
    Region::String
end
StructTypes.StructType(::Type{DirectDistributionInformationType}) = StructTypes.Struct()


"Used to identify other services, collections, visualizations, granules, and other metadata types and resources that are associated with or dependent on this collection, including parent-child relationships."
struct MetadataAssociationType <: AbstractJSON
    "Free-text description of the association between this collection record and the target metadata record."
    Description::Union{Nothing,String}
    "The set of supported values for MetadataAssociationType.Type."
    Type::Union{Nothing,String}
    "The version of the metadata record."
    Version::Union{Nothing,String}
    "This is the ID of the metadata record.  It is only unique when combined with the version."
    EntryId::String
end
StructTypes.StructType(::Type{MetadataAssociationType}) = StructTypes.Struct()


"This entity is used to define characteristics."
struct CharacteristicType <: AbstractJSON
    "This entity contains the additional attribute data types."
    DataType::String
    "Units associated with the Characteristic attribute value."
    Unit::String
    "Description of the Characteristic attribute."
    Description::String
    "The value of the Characteristic attribute."
    Value::String
    "The name of the characteristic attribute."
    Name::String
end
StructTypes.StructType(::Type{CharacteristicType}) = StructTypes.Struct()


"Non Gridded Range Resolutions object describes range resolution data for non gridded data products."
struct HorizontalDataResolutionNonGriddedRangeType <: AbstractJSON
    "Units of measure used for the geodetic latitude and longitude resolution values (e.g., decimal degrees)."
    Unit::Union{Nothing,String}
    "This element describes the instrument scanning direction."
    ScanDirection::Union{Nothing,String}
    "The minimum, minimum difference between two adjacent values on a horizontal plane in the X axis. In most cases this is along the longitudinal axis."
    MinimumXDimension::Union{Nothing,Float64}
    "The maximum, minimum difference between two adjacent values on a horizontal plane in the X axis. In most cases this is along the longitudinal axis."
    MaximumXDimension::Union{Nothing,Float64}
    "This element describes the angle of the measurement with respect to the instrument that give an understanding of the specified resolution."
    ViewingAngleType::Union{Nothing,String}
    "The minimum, minimum difference between two adjacent values on a horizontal plan in the Y axis. In most cases this is along the latitudinal axis."
    MinimumYDimension::Union{Nothing,Float64}
    "The maximum, minimum difference between two adjacent values on a horizontal plan in the Y axis. In most cases this is along the latitudinal axis."
    MaximumYDimension::Union{Nothing,Float64}
end
StructTypes.StructType(::Type{HorizontalDataResolutionNonGriddedRangeType}) =
    StructTypes.Struct()


"For paleoclimate or geologic data, PaleoTemporalCoverage is the length of time represented by the data collected. PaleoTemporalCoverage should be used when the data spans time frames earlier than yyyy-mm-dd = 0001-01-01."
struct PaleoTemporalCoverageType <: AbstractJSON
    "A string indicating the number of years closest to the present time, including units, e.g., 10 ka.  Units may be Ga (billions of years before present), Ma (millions of years before present), ka (thousands of years before present) or ybp (years before present)."
    EndDate::Union{Nothing,String}
    "A string indicating the number of years furthest back in time, including units, e.g., 100 Ga.  Units may be Ga (billions of years before present), Ma (millions of years before present), ka (thousands of years before present) or ybp (years before present)."
    StartDate::Union{Nothing,String}
    "Hierarchy of terms indicating units of geologic time, i.e., eon (e.g, Phanerozoic), era (e.g., Cenozoic), period (e.g., Paleogene), epoch (e.g., Oligocene), and stage or age (e.g, Chattian)."
    ChronostratigraphicUnits::Union{Nothing,Vector{ChronostratigraphicUnitType}}
end
StructTypes.StructType(::Type{PaleoTemporalCoverageType}) = StructTypes.Struct()


"This element and all of its sub elements exist for display purposes. It allows a data provider to provide archive and distribution information up front to an end user, to help them decide if they can use the product."
struct ArchiveAndDistributionInformationType <: AbstractJSON
    "This element defines a single artifact that is distributed by the data provider. This element only includes the distributable artifacts that can be obtained by the user without the user having to invoke a service. These should be documented in the UMM-S specification."
    FileDistributionInformation::Union{Nothing,Vector{Union{Dict,Dict}}}
    "This element defines a single archive artifact which a data provider would like to inform an end user that it exists."
    FileArchiveInformation::Union{Nothing,Vector{Union{Dict,Dict}}}
end
StructTypes.StructType(::Type{ArchiveAndDistributionInformationType}) = StructTypes.Struct()


"This element stores the DOI (Digital Object Identifier) that identifies the collection. Note: The values should start with the directory indicator which in ESDIS' case is 10.  If the DOI was registered through ESDIS, the beginning of the string should be 10.5067. The DOI URL is not stored here; it should be stored as a RelatedURL. The DOI organization that is responsible for creating the DOI is described in the Authority element. For ESDIS records the value of https://doi.org/ should be used. NASA metadata providers are strongly encouraged to include DOI and DOI Authority for their collections using CollectionDOI property."
struct DoiDoiType <: AbstractJSON
    "This element stores the DOI (Digital Object Identifier) that identifies the collection.  Note: The values should start with the directory indicator which in ESDIS' case is 10.  If the DOI was registered through ESDIS, the beginning of the string should be 10.5067. The DOI URL is not stored here; it should be stored as a RelatedURL."
    DOI::String
    "The Authority (who created it or owns it) of a unique identifier."
    Authority::Union{Nothing,String}
end
StructTypes.StructType(::Type{DoiDoiType}) = StructTypes.Struct()


"Describes key bibliographic citations pertaining to the data."
struct PublicationReferenceType <: AbstractJSON
    "The ISBN of the publication."
    ISBN::Union{Nothing,String}
    "The report number of the publication."
    ReportNumber::Union{Nothing,String}
    "The author of the publication."
    Author::Union{Nothing,String}
    "The date of the publication."
    PublicationDate::Union{Nothing,String}
    "The name of the series of the publication."
    Series::Union{Nothing,String}
    "Describes the online resource pertaining to the data."
    OnlineResource::Union{Nothing,OnlineResourceType}
    "The publisher of the publication."
    Publisher::Union{Nothing,String}
    "Additional free-text reference information about the publication."
    OtherReferenceDetails::Union{Nothing,String}
    "The publication pages that are relevant."
    Pages::Union{Nothing,String}
    "The publication place of the publication."
    PublicationPlace::Union{Nothing,String}
    "A title type that defines the min and max lengths of all titles."
    Title::Union{Nothing,String}
    "The issue of the publication."
    Issue::Union{Nothing,String}
    "The edition of the publication."
    Edition::Union{Nothing,String}
    "This element stores the DOI (Digital Object Identifier) that identifies the collection. Note: The values should start with the directory indicator which in ESDIS' case is 10.  If the DOI was registered through ESDIS, the beginning of the string should be 10.5067. The DOI URL is not stored here; it should be stored as a RelatedURL. The DOI organization that is responsible for creating the DOI is described in the Authority element. For ESDIS records the value of https://doi.org/ should be used. NASA metadata providers are strongly encouraged to include DOI and DOI Authority for their collections using CollectionDOI property."
    DOI::Union{Nothing,DoiDoiType}
    "The publication volume number."
    Volume::Union{Nothing,String}
end
StructTypes.StructType(::Type{PublicationReferenceType}) = StructTypes.Struct()


"Information describing the scientific endeavor(s) with which the collection is associated. Scientific endeavors include campaigns, projects, interdisciplinary science investigations, missions, field experiments, etc. The controlled vocabularies for project names are maintained in the Keyword Management System (KMS)"
struct ProjectType <: AbstractJSON
    "The ending data of the campaign."
    EndDate::Union{Nothing,String}
    "The name of the campaign/experiment (e.g. Global climate observing system)."
    Campaigns::Union{Nothing,Vector{String}}
    "The starting date of the campaign."
    StartDate::Union{Nothing,String}
    "The unique identifier by which a project or campaign/experiment is known. The campaign/project is the scientific endeavor associated with the acquisition of the collection. Collections may be associated with multiple campaigns."
    ShortName::String
    "The expanded name of the campaign/experiment (e.g. Global climate observing system)."
    LongName::Union{Nothing,String}
end
StructTypes.StructType(::Type{ProjectType}) = StructTypes.Struct()


"Stores the start and end date/time of a collection."
struct RangeDateTimeType <: AbstractJSON
    "The time when the temporal coverage period being described ended."
    EndingDateTime::Union{Nothing,String}
    "The time when the temporal coverage period being described began."
    BeginningDateTime::String
end
StructTypes.StructType(::Type{RangeDateTimeType}) = StructTypes.Struct()


struct LineType <: AbstractJSON
    Points::Vector{PointType}
end
StructTypes.StructType(::Type{LineType}) = StructTypes.Struct()


"Formerly called Internal Directory Name (IDN) Node (IDN_Node). This element has been used historically by the GCMD internally to identify association, responsibility and/or ownership of the dataset, service or supplemental information. Note: This field only occurs in the DIF. When a DIF record is retrieved in the ECHO10 or ISO 19115 formats, this element will not be translated."
struct DirectoryNameType <: AbstractJSON
    "The unique name."
    ShortName::String
    "The expanded or long name related to the short name."
    LongName::Union{Nothing,String}
end
StructTypes.StructType(::Type{DirectoryNameType}) = StructTypes.Struct()


"Defines the minimum and maximum value for one dimension of a two dimensional coordinate system."
struct TilingCoordinateType <: AbstractJSON
    MinimumValue::Union{Nothing,Float64}
    MaximumValue::Union{Nothing,Float64}
end
StructTypes.StructType(::Type{TilingCoordinateType}) = StructTypes.Struct()


"This class defines a number of the data products horizontal data resolution. The horizontal data resolution is defined as the smallest horizontal distance between successive elements of data in a dataset. This is synonymous with terms such as ground sample distance, sample spacing and pixel size. It is to be noted that the horizontal data resolution could be different in the two horizontal dimensions. Also, it is different from the spatial resolution of an instrument, which is the minimum distance between points that an instrument can see as distinct."
struct HorizontalDataResolutionType <: AbstractJSON
    "Point Resolution object describes a data product that is from a point source."
    PointResolution::Union{Nothing,String}
    "Non Gridded Resolutions object describes resolution data for non gridded data products."
    NonGriddedResolutions::Union{Nothing,Vector{HorizontalDataResolutionNonGriddedType}}
    "Gridded Resolutions object describes resolution data for gridded data products."
    GriddedResolutions::Union{Nothing,Vector{HorizontalDataResolutionGriddedType}}
    "Gridded Range Resolutions object describes range resolution data for gridded data products."
    GriddedRangeResolutions::Union{Nothing,Vector{HorizontalDataResolutionGriddedRangeType}}
    "Generic Resolutions object describes general resolution data for a data product where it is not known if a data product is gridded or not."
    GenericResolutions::Union{Nothing,Vector{HorizontalDataGenericResolutionType}}
    "Varies Resolution object describes a data product that has a number of resolution values."
    VariesResolution::Union{Nothing,String}
    "Non Gridded Range Resolutions object describes range resolution data for non gridded data products."
    NonGriddedRangeResolutions::Union{
        Nothing,
        Vector{HorizontalDataResolutionNonGriddedRangeType},
    }
end
StructTypes.StructType(::Type{HorizontalDataResolutionType}) = StructTypes.Struct()


"The reference frame or system from which altitude is measured. The term 'altitude' is used instead of the common term 'elevation' to conform to the terminology in Federal Information Processing Standards 70-1 and 173. The information contains the datum name, distance units and encoding method, which provide the definition for the system."
struct AltitudeSystemDefinitionType <: AbstractJSON
    "The identification given to the level surface taken as the surface of reference from which measurements are compared."
    DatumName::Union{Nothing,String}
    "The units in which altitude measurements are recorded."
    DistanceUnits::Union{Nothing,String}
    "The minimum distance possible between two adjacent values, expressed in distance units of measure for the collection."
    Resolutions::Union{Nothing,Vector{Float64}}
end
StructTypes.StructType(::Type{AltitudeSystemDefinitionType}) = StructTypes.Struct()


"This element stores the DOI (Digital Object Identifier) that identifies the collection. Note: The values should start with the directory indicator which in ESDIS' case is 10.  If the DOI was registered through ESDIS, the beginning of the string should be 10.5067. The DOI URL is not stored here; it should be stored as a RelatedURL. The DOI organization that is responsible for creating the DOI is described in the Authority element. For ESDIS records the value of https://doi.org/ should be used. NASA metadata providers are strongly encouraged to include DOI and DOI Authority for their collections using CollectionDOI property."
struct AssociatedDoiType <: AbstractJSON
    "This element stores the DOI (Digital Object Identifier) that identifies the collection.  Note: The values should start with the directory indicator which in ESDIS' case is 10.  If the DOI was registered through ESDIS, the beginning of the string should be 10.5067. The DOI URL is not stored here; it should be stored as a RelatedURL."
    DOI::String
    "The Authority (who created it or owns it) of a unique identifier."
    Authority::Union{Nothing,String}
    "A title type that defines the min and max lengths of all titles."
    Title::Union{Nothing,String}
end
StructTypes.StructType(::Type{AssociatedDoiType}) = StructTypes.Struct()


"Building block text fields used to construct the recommended language for citing the collection in professional scientific literature.  The citation language constructed from these fields references the collection itself, and is not designed for listing bibliographic references of scientific research articles arising from search results. A list of references related to the research results should be in the Publication Reference element."
struct ResourceCitationType <: AbstractJSON
    "The volume or issue number of the publication (if applicable)."
    IssueIdentification::Union{Nothing,String}
    "The version of the metadata record."
    Version::Union{Nothing,String}
    "The name of the organization(s) or individual(s) with primary intellectual responsibility for the collection's development."
    Creator::Union{Nothing,String}
    "The name of the data series, or aggregate data of which the data is a part."
    SeriesName::Union{Nothing,String}
    "Additional free-text citation information."
    OtherCitationDetails::Union{Nothing,String}
    "Describes the online resource pertaining to the data."
    OnlineResource::Union{Nothing,OnlineResourceType}
    "The name of the individual or organization that made the collection available for release."
    Publisher::Union{Nothing,String}
    "The name of the city (and state or province and country if needed) where the collection was made available for release."
    ReleasePlace::Union{Nothing,String}
    "The mode in which the data are represented, e.g. atlas, image, profile, text, etc."
    DataPresentationForm::Union{Nothing,String}
    "A title type that defines the min and max lengths of all titles."
    Title::Union{Nothing,String}
    "The individual(s) responsible for changing the data in the collection."
    Editor::Union{Nothing,String}
    "The date when the collection was made available for release."
    ReleaseDate::Union{Nothing,String}
end
StructTypes.StructType(::Type{ResourceCitationType}) = StructTypes.Struct()


"Information which describes the temporal range or extent of a specific collection."
struct TemporalExtentType <: AbstractJSON
    "Stores the start and end date/time of a collection."
    RangeDateTimes::Union{Nothing,Vector{RangeDateTimeType}}
    SingleDateTimes::Union{Nothing,Vector{String}}
    "Setting the Ends At Present Flag to 'True' indicates that a data collection which covers, temporally, a discontinuous range, currently ends at the present date.  Setting the Ends at Present flag to 'True' eliminates the need to continuously update the Range Ending Time for collections where granules are continuously being added to the collection inventory."
    EndsAtPresentFlag::Union{Nothing,Bool}
    "Temporal information about a collection having granules collected at a regularly occurring period.   Information includes the start and end dates of the period, duration unit and value, and cycle duration unit and value."
    PeriodicDateTimes::Union{Nothing,Vector{PeriodicDateTimeType}}
    "The precision (position in number of places to right of decimal point) of seconds used in measurement."
    PrecisionOfSeconds::Union{Nothing,Int64}
end
StructTypes.StructType(::Type{TemporalExtentType}) = StructTypes.Struct()


"Child object on an instrument. Has all the same fields as instrument, minus the list of child instruments."
struct InstrumentChildType <: AbstractJSON
    "The expanded name of the primary sensory instrument. (e.g. Advanced Spaceborne Thermal Emission and Reflective Radiometer, Clouds and the Earth's Radiant Energy System, Human Observation)."
    Technique::Union{Nothing,String}
    "The unique name of the platform."
    ShortName::String
    "The expanded or long name related to the short name of the platform."
    LongName::Union{Nothing,String}
    "Instrument-specific characteristics, e.g., Wavelength, SwathWidth, Field of View. The characteristic names must be unique on this instrument; however the names do not have to be unique across instruments."
    Characteristics::Union{Nothing,Vector{CharacteristicType}}
end
StructTypes.StructType(::Type{InstrumentChildType}) = StructTypes.Struct()


"A boundary is set of points connected by straight lines representing a polygon on the earth. It takes a minimum of three points to make a boundary. Points must be specified in counter-clockwise order and closed (the first and last vertices are the same)."
struct BoundaryType <: AbstractJSON
    Points::Vector{PointType}
end
StructTypes.StructType(::Type{BoundaryType}) = StructTypes.Struct()


struct VerticalCoordinateSystemType <: AbstractJSON
    "The reference frame or system from which altitude is measured. The term 'altitude' is used instead of the common term 'elevation' to conform to the terminology in Federal Information Processing Standards 70-1 and 173. The information contains the datum name, distance units and encoding method, which provide the definition for the system."
    AltitudeSystemDefinition::Union{Nothing,AltitudeSystemDefinitionType}
    "The reference frame or system from which depth is measured. The information contains the datum name, distance units and encoding method, which provide the definition for the system."
    DepthSystemDefinition::Union{Nothing,DepthSystemDefinitionType}
end
StructTypes.StructType(::Type{VerticalCoordinateSystemType}) = StructTypes.Struct()


"Represents Internet sites that contain information related to the data, as well as related Internet sites such as project home pages, related data archives/servers, metadata extensions, online software packages, web mapping services, and calibration/validation data."
struct RelatedUrlType <: AbstractJSON
    "Represents the information needed for a DistributionURL where data is retrieved."
    GetData::Union{Nothing,GetDataType}
    "A keyword describing the distinct content type of the online resource to this resource. (e.g., 'DATACENTER URL', 'DATA CONTACT URL', 'DISTRIBUTION URL'). The valid values are contained in the KMS System: https://gcmd.earthdata.nasa.gov/KeywordViewer/scheme/all/8759ab63-ac04-4136-bc25-0c00eece1096?gtm_keyword=Related%20URL%20Content%20Types&gtm_scheme=rucontenttype."
    URLContentType::String
    "Description of the web page at this URL."
    Description::Union{Nothing,String}
    "A keyword describing the subtype of the online resource to this resource. This further helps the GUI to know what to do with this resource. (e.g., 'MEDIA', 'BROWSE', 'OPENDAP', 'OPENSEARCH', 'WEB COVERAGE SERVICES', 'WEB FEATURE SERVICES', 'WEB MAPPING SERVICES', 'SSW', 'ESI'). The valid values are contained in the KMS System: https://gcmd.earthdata.nasa.gov/KeywordViewer/scheme/all/8759ab63-ac04-4136-bc25-0c00eece1096?gtm_keyword=Related%20URL%20Content%20Types&gtm_scheme=rucontenttype."
    Subtype::Union{Nothing,String}
    "Represents a Service through a URL where the service will act on data and return the result to the caller."
    GetService::Union{Nothing,GetServiceType}
    "The URL for the relevant web page (e.g., the URL of the responsible organization's home page, the URL of the collection landing page, the URL of the download site for the collection)."
    URL::String
    "A keyword describing the type of the online resource to this resource. This helps the GUI to know what to do with this resource. (e.g., 'GET DATA', 'GET SERVICE', 'GET VISUALIZATION'). The valid values are contained in the KMS System: https://gcmd.earthdata.nasa.gov/KeywordViewer/scheme/all/8759ab63-ac04-4136-bc25-0c00eece1096?gtm_keyword=Related%20URL%20Content%20Types&gtm_scheme=rucontenttype."
    Type::String
end
StructTypes.StructType(::Type{RelatedUrlType}) = StructTypes.Struct()


"This class defines the horizontal spatial extents coordinate system and the data product's horizontal data resolution. The horizontal data resolution is defined as the smallest horizontal distance between successive elements of data in a dataset. This is synonymous with terms such as ground sample distance, sample spacing and pixel size. It is to be noted that the horizontal data resolution could be different in the two horizontal dimensions. Also, it is different from the spatial resolution of an instrument, which is the minimum distance between points that an instrument can see as distinct."
struct ResolutionAndCoordinateSystemType <: AbstractJSON
    "This class defines a number of the data products horizontal data resolution. The horizontal data resolution is defined as the smallest horizontal distance between successive elements of data in a dataset. This is synonymous with terms such as ground sample distance, sample spacing and pixel size. It is to be noted that the horizontal data resolution could be different in the two horizontal dimensions. Also, it is different from the spatial resolution of an instrument, which is the minimum distance between points that an instrument can see as distinct."
    HorizontalDataResolution::Union{Nothing,HorizontalDataResolutionType}
    "This element defines what a description is."
    Description::Union{Nothing,String}
    "This element describes the local coordinate system for the data product."
    LocalCoordinateSystem::Union{Nothing,LocalCoordinateSystemType}
    "This element describes the geodetic model for the data product."
    GeodeticModel::Union{Nothing,GeodeticModelType}
end
StructTypes.StructType(::Type{ResolutionAndCoordinateSystemType}) = StructTypes.Struct()


"Information about a two-dimensional tiling system related to this collection."
struct TilingIdentificationSystemType <: AbstractJSON
    TilingIdentificationSystemName::String
    "Defines the minimum and maximum value for one dimension of a two dimensional coordinate system."
    Coordinate2::TilingCoordinateType
    "Defines the minimum and maximum value for one dimension of a two dimensional coordinate system."
    Coordinate1::TilingCoordinateType
end
StructTypes.StructType(::Type{TilingIdentificationSystemType}) = StructTypes.Struct()


"Contains the excluded boundaries from the GPolygon."
struct ExclusiveZoneType <: AbstractJSON
    Boundaries::Vector{BoundaryType}
end
StructTypes.StructType(::Type{ExclusiveZoneType}) = StructTypes.Struct()


"Defines the contact information of a data center or data contact."
struct ContactInformationType <: AbstractJSON
    "Contact addresses."
    Addresses::Union{Nothing,Vector{AddressType}}
    "Mechanisms of contacting."
    ContactMechanisms::Union{Nothing,Vector{ContactMechanismType}}
    "Time period when the contact answers questions or provides services."
    ServiceHours::Union{Nothing,String}
    "A URL associated with the contact, e.g., the home page for the DAAC which is responsible for the collection."
    RelatedUrls::Union{Nothing,Vector{RelatedUrlType}}
    "Supplemental instructions on how or when to contact the responsible party."
    ContactInstruction::Union{Nothing,String}
end
StructTypes.StructType(::Type{ContactInformationType}) = StructTypes.Struct()


"Information about the device used to measure or record data in this collection, including direct human observation. In cases where instruments have a single child instrument or the instrument and child instrument are used synonymously (e.g. AVHRR), both Instrument and ComposedOf should be recorded. The child instrument information is represented in a separate section. The controlled vocabulary for instrument names is maintained in the Keyword Management System (KMS)."
struct InstrumentType <: AbstractJSON
    ComposedOf::Union{Nothing,Vector{InstrumentChildType}}
    "The expanded name of the primary sensory instrument. (e.g. Advanced Spaceborne Thermal Emission and Reflective Radiometer, Clouds and the Earth's Radiant Energy System, Human Observation)."
    Technique::Union{Nothing,String}
    "The unique name of the platform."
    ShortName::String
    "The expanded or long name related to the short name of the platform."
    LongName::Union{Nothing,String}
    "The operation mode applied on the instrument when acquiring the granule data."
    OperationalModes::Union{Nothing,Vector{String}}
    "Number of instruments used on the instrument when acquiring the granule data."
    NumberOfInstruments::Union{Nothing,Int64}
    "Instrument-specific characteristics, e.g., Wavelength, SwathWidth, Field of View. The characteristic names must be unique on this instrument; however the names do not have to be unique across instruments."
    Characteristics::Union{Nothing,Vector{CharacteristicType}}
end
StructTypes.StructType(::Type{InstrumentType}) = StructTypes.Struct()


struct GPolygonType <: AbstractJSON
    "Contains the excluded boundaries from the GPolygon."
    ExclusiveZone::Union{Nothing,ExclusiveZoneType}
    "A boundary is set of points connected by straight lines representing a polygon on the earth. It takes a minimum of three points to make a boundary. Points must be specified in counter-clockwise order and closed (the first and last vertices are the same)."
    Boundary::BoundaryType
end
StructTypes.StructType(::Type{GPolygonType}) = StructTypes.Struct()


"This entity stores the reference frame or system from which horizontal and vertical spatial domains are measured. The horizontal reference frame includes a Geodetic Model, Geographic Coordinates, and Local Coordinates. The Vertical reference frame includes altitudes (elevations) and depths."
struct SpatialInformationType <: AbstractJSON
    "Denotes whether the spatial coverage of the collection is horizontal, vertical, horizontal and vertical, orbit, or vertical and orbit."
    SpatialCoverageType::String
    VerticalCoordinateSystem::Union{Nothing,VerticalCoordinateSystemType}
end
StructTypes.StructType(::Type{SpatialInformationType}) = StructTypes.Struct()


"Describes the relevant platforms used to acquire the data in the collection. The controlled vocabularies for platform types and names are maintained in the Keyword Management System (KMS)."
struct PlatformType <: AbstractJSON
    "The unique name of the platform."
    ShortName::String
    "The most relevant platform type."
    Type::Union{Nothing,String}
    "The expanded or long name related to the short name of the platform."
    LongName::Union{Nothing,String}
    Instruments::Union{Nothing,Vector{InstrumentType}}
    "Platform-specific characteristics, e.g., Equator Crossing Time, Inclination Angle, Orbital Period. The characteristic names must be unique on this platform; however the names do not have to be unique across platforms."
    Characteristics::Union{Nothing,Vector{CharacteristicType}}
end
StructTypes.StructType(::Type{PlatformType}) = StructTypes.Struct()


struct GeometryType <: AbstractJSON
    BoundingRectangles::Union{Nothing,Vector{BoundingRectangleType}}
    GPolygons::Union{Nothing,Vector{GPolygonType}}
    Points::Union{Nothing,Vector{PointType}}
    Lines::Union{Nothing,Vector{LineType}}
    CoordinateSystem::String
end
StructTypes.StructType(::Type{GeometryType}) = StructTypes.Struct()


struct ContactGroupType <: AbstractJSON
    "This is the contact person or group that is not affiliated with the data centers."
    NonDataCenterAffiliation::Union{Nothing,String}
    "A Level 3 UUID, see wiki link http://en.wikipedia.org/wiki/Universally_unique_identifier#Version_4_.28random.29"
    Uuid::Union{Nothing,String}
    "Defines the contact information of a data center or data contact."
    ContactInformation::Union{Nothing,ContactInformationType}
    "This is the contact group name."
    GroupName::String
    "This is the roles of the data contact."
    Roles::Vector{String}
end
StructTypes.StructType(::Type{ContactGroupType}) = StructTypes.Struct()


struct ContactPersonType <: AbstractJSON
    "This is the contact person or group that is not affiliated with the data centers."
    NonDataCenterAffiliation::Union{Nothing,String}
    "A Level 3 UUID, see wiki link http://en.wikipedia.org/wiki/Universally_unique_identifier#Version_4_.28random.29"
    Uuid::Union{Nothing,String}
    "Defines the contact information of a data center or data contact."
    ContactInformation::Union{Nothing,ContactInformationType}
    "Last name of the individual."
    LastName::String
    "First name of the individual."
    FirstName::Union{Nothing,String}
    "This is the roles of the data contact."
    Roles::Vector{String}
    "Middle name of the individual."
    MiddleName::Union{Nothing,String}
end
StructTypes.StructType(::Type{ContactPersonType}) = StructTypes.Struct()


"Information about a collection with horizontal spatial coverage."
struct HorizontalSpatialDomainType <: AbstractJSON
    "The appropriate numeric or alpha code used to identify the various zones in the collection's grid coordinate system."
    ZoneIdentifier::Union{Nothing,String}
    "This class defines the horizontal spatial extents coordinate system and the data product's horizontal data resolution. The horizontal data resolution is defined as the smallest horizontal distance between successive elements of data in a dataset. This is synonymous with terms such as ground sample distance, sample spacing and pixel size. It is to be noted that the horizontal data resolution could be different in the two horizontal dimensions. Also, it is different from the spatial resolution of an instrument, which is the minimum distance between points that an instrument can see as distinct."
    ResolutionAndCoordinateSystem::Union{Nothing,ResolutionAndCoordinateSystemType}
    Geometry::GeometryType
end
StructTypes.StructType(::Type{HorizontalSpatialDomainType}) = StructTypes.Struct()


"Defines a data center which is either an organization or institution responsible for distributing, archiving, or processing the data, etc."
struct DataCenterType <: AbstractJSON
    "A Level 3 UUID, see wiki link http://en.wikipedia.org/wiki/Universally_unique_identifier#Version_4_.28random.29"
    Uuid::Union{Nothing,String}
    "This is the contact groups of the data center."
    ContactGroups::Union{Nothing,Vector{ContactGroupType}}
    "Defines the contact information of a data center or data contact."
    ContactInformation::Union{Nothing,ContactInformationType}
    "This is the contact persons of the data center."
    ContactPersons::Union{Nothing,Vector{ContactPersonType}}
    "The unique name of the data center."
    ShortName::String
    "The expanded or long name related to the short name."
    LongName::Union{Nothing,String}
    "This is the roles of the data center."
    Roles::Vector{String}
end
StructTypes.StructType(::Type{DataCenterType}) = StructTypes.Struct()


"Specifies the geographic and vertical (altitude, depth) coverage of the data."
struct SpatialExtentType <: AbstractJSON
    "Information about a collection with horizontal spatial coverage."
    HorizontalSpatialDomain::Union{Nothing,HorizontalSpatialDomainType}
    "Denotes whether the collection's spatial coverage requires horizontal, vertical, horizontal and vertical, orbit, or vertical and orbit in the spatial domain and coordinate system definitions."
    SpatialCoverageType::Union{Nothing,String}
    VerticalSpatialDomains::Union{Nothing,Vector{VerticalSpatialDomainType}}
    GranuleSpatialRepresentation::String
    "Orbit parameters for the collection used by the Orbital Backtrack Algorithm."
    OrbitParameters::Union{Nothing,OrbitParametersType}
end
StructTypes.StructType(::Type{SpatialExtentType}) = StructTypes.Struct()


struct UMM_C <: AbstractJSON
    "Dates related to activities involving the collection data.  For example, Creation date is the date that the collection data first entered the data archive system."
    DataDates::Union{Nothing,Vector{DateType}}
    "Controlled Science Keywords describing the collection.  The controlled vocabulary for Science Keywords is maintained in the Keyword Management System (KMS)."
    ScienceKeywords::Vector{ScienceKeywordType}
    "Information about the data centers responsible for this collection and its metadata."
    DataCenters::Vector{DataCenterType}
    "Free-text information about the quality of the data in the collection or any quality assurance procedures followed in producing the data described in the metadata. Suggestions for information to include in the Quality field: Description should be succinct. Include indicators of data quality or quality flags. Include recognized or potential problems with quality. Established quality control mechanisms should be included. Established quantitative quality measurements should be included."
    Quality::Union{Nothing,String}
    "This object requires any metadata record that is validated by this schema to provide information about the schema."
    MetadataSpecification::MetadataSpecificationType
    "This element allows end users to get direct access to data products that are stored in the Amazon Web Service (AWS) S3 buckets. The sub elements include S3 credentials end point and a documentation URL as well as bucket prefix names and an AWS region."
    DirectDistributionInformation::Union{Nothing,DirectDistributionInformationType}
    "One or more words or phrases that describe the temporal resolution of the dataset."
    TemporalKeywords::Union{Nothing,Vector{String}}
    "This element is used to identify other services, collections, visualizations, granules, and other metadata types and resources that are associated with or dependent on the data described by the metadata. This element is also used to identify a parent metadata record if it exists. This usage should be reserved for instances where a group of metadata records are subsets that can be better represented by one parent metadata record, which describes the entire set. In some instances, a child may point to more than one parent. The EntryId is the same as the element described elsewhere in this document where it contains an ID and Version."
    MetadataAssociations::Union{Nothing,Vector{MetadataAssociationType}}
    "This element is used to identify the collection's ready for end user consumption latency from when the data was acquired by an instrument. NEAR_REAL_TIME is defined to be ready for end user consumption 1 to 3 hours after data acquisition. LOW_LATENCY is defined to be ready for consumption 3 to 24 hours after data acquisition. EXPEDITED is defined to be 1 to 4 days after data acquisition. SCIENCE_QUALITY is defined to mean that a collection has been fully and completely processed which usually takes between 2 to 3 weeks after data acquisition. OTHER is defined for collection where the latency is between EXPEDITED and SCIENCE_QUALITY."
    CollectionDataType::Union{Nothing,String}
    "For paleoclimate or geologic data, PaleoTemporalCoverage is the length of time represented by the data collected. PaleoTemporalCoverage should be used when the data spans time frames earlier than yyyy-mm-dd = 0001-01-01."
    PaleoTemporalCoverages::Union{Nothing,Vector{PaleoTemporalCoverageType}}
    "Specifies the geographic and vertical (altitude, depth) coverage of the data."
    SpatialExtent::SpatialExtentType
    "This element describes any data/service related URLs that include project home pages, services, related data archives/servers, metadata extensions, direct links to online software packages, web mapping services, links to images, or other data."
    RelatedUrls::Union{Nothing,Vector{RelatedUrlType}}
    "The version of the metadata record."
    Version::String
    "Describes key bibliographic citations pertaining to the collection."
    PublicationReferences::Union{Nothing,Vector{PublicationReferenceType}}
    "Controlled hierarchical keywords used to specify the spatial location of the collection.   The controlled vocabulary for spatial keywords is maintained in the Keyword Management System (KMS).  The Spatial Keyword hierarchy includes one or more of the following layers: Category (e.g., Continent), Type (e.g. Africa), Subregion1 (e.g., Central Africa), Subregion2 (e.g., Cameroon), and Subregion3. DetailedLocation exists outside the hierarchy."
    LocationKeywords::Union{Nothing,Vector{LocationKeywordType}}
    "This is deprecated and will be removed. Use LocationKeywords instead. Controlled hierarchical keywords used to specify the spatial location of the collection.   The controlled vocabulary for spatial keywords is maintained in the Keyword Management System (KMS).  The Spatial Keyword hierarchy includes one or more of the following layers: Location_Category (e.g., Continent), Location_Type (e.g. Africa), Location_Subregion1 (e.g., Central Africa), Location_Subregion2 (e.g., Cameroon), and Location_Subregion3."
    SpatialKeywords::Union{Nothing,Vector{String}}
    "The name of the scientific program, field campaign, or project from which the data were collected. This element is intended for the non-space assets such as aircraft, ground systems, balloons, sondes, ships, etc. associated with campaigns. This element may also cover a long term project that continuously creates new data sets — like MEaSUREs from ISCCP and NVAP or CMARES from MISR. Project also includes the Campaign sub-element to support multiple campaigns under the same project."
    Projects::Union{Nothing,Vector{ProjectType}}
    "Information required to properly cite the collection in professional scientific literature. This element provides information for constructing a citation for the item itself, and is not designed for listing bibliographic references of scientific research articles arising from search results. A list of references related to the research results should be in the Publication Reference element."
    CollectionCitations::Union{Nothing,Vector{ResourceCitationType}}
    "Describes the language used in the preparation, storage, and description of the collection. It is the language of the collection data themselves.   It does not refer to the language used in the metadata record (although this may be the same language). The name of the language used for this field is defined in ISO 639."
    MetadataLanguage::Union{Nothing,String}
    "This class contains attributes which describe the temporal range of a specific collection. Temporal Extent includes a specification of the Temporal Range Type of the collection, which is one of Range Date Time, Single Date Time, or Periodic Date Time"
    TemporalExtents::Vector{TemporalExtentType}
    "A title type that defines the min and max lengths of all titles."
    EntryTitle::String
    "Describes the language used in the preparation, storage, and description of the collection. It is the language of the collection data themselves.   It does not refer to the language used in the metadata record (although this may be the same language). The name of the language used for this field is defined in ISO 639."
    DataLanguage::Union{Nothing,String}
    "Information about the personnel responsible for this collection and its metadata."
    ContactPersons::Union{Nothing,Vector{ContactPersonType}}
    "This element stores DOIs that are associated with the collection such as from campaigns and other related sources. Note: The values should start with the directory indicator which in ESDIS' case is 10.  If the DOI was registered through ESDIS, the beginning of the string should be 10.5067. The DOI URL is not stored here; it should be stored as a RelatedURL. The DOI organization that is responsible for creating the DOI is described in the Authority element. For ESDIS records the value of https://doi.org/ should be used."
    AssociatedDOIs::Union{Nothing,Vector{AssociatedDoiType}}
    "Information about the relevant platform(s) used to acquire the data in the collection. The controlled vocabulary for platform types is maintained in the Keyword Management System (KMS), and includes Spacecraft, Aircraft, Vessel, Buoy, Platform, Station, Network, Human, etc."
    Platforms::Vector{PlatformType}
    "This element and all of its sub elements exist for display purposes. It allows a data provider to provide archive and distribution information up front to an end user, to help them decide if they can use the product."
    ArchiveAndDistributionInformation::Union{Nothing,ArchiveAndDistributionInformationType}
    "Information about any constraints for accessing the data set. This includes any special restrictions, legal prerequisites, limitations and/or warnings on obtaining the data set."
    AccessConstraints::Union{Nothing,AccessConstraintsType}
    "Describes the purpose and/or intended use of data in this collection."
    Purpose::Union{Nothing,String}
    "This element describes the production status of the data set. There are five choices for Data Providers: PLANNED refers to data sets to be collected in the future and are thus unavailable at the present time. For Example: The Hydro spacecraft has not been launched, but information on planned data sets may be available. ACTIVE refers to data sets currently in production or data that is continuously being collected or updated. For Example: data from the AIRS instrument on Aqua is being collected continuously. COMPLETE refers to data sets in which no updates or further data collection will be made. For Example: Nimbus-7 SMMR data collection has been completed. DEPRECATED refers to data sets that have been retired, but still can be retrieved. Usually newer products exist that replace the retired data set. NOT APPLICABLE refers to data sets in which a collection progress is not applicable such as a calibration collection. There is a sixth value of NOT PROVIDED that should not be used by a data provider. It is currently being used as a value when a correct translation cannot be done with the current valid values, or when the value is not provided by the data provider."
    CollectionProgress::String
    "The data’s distinctive attributes of the collection (i.e. attributes used to describe the unique characteristics of the collection which extend beyond those defined)."
    AdditionalAttributes::Union{Nothing,Vector{AdditionalAttributeType}}
    "Information about the personnel groups responsible for this collection and its metadata."
    ContactGroups::Union{Nothing,Vector{ContactGroupType}}
    "Allows authors to provide words or phrases outside of the controlled Science Keyword vocabulary, to further describe the collection."
    AncillaryKeywords::Union{Nothing,Vector{String}}
    "Name of the two-dimensional tiling system for the collection.  Previously called TwoDCoordinateSystem."
    TilingIdentificationSystems::Union{Nothing,Vector{TilingIdentificationSystemType}}
    "This element contains the Processing Level Id and the Processing Level Description"
    ProcessingLevel::ProcessingLevelType
    "Dates related to activities involving the metadata record itself.  For example, Future Review date is the date that the metadata record is scheduled to be reviewed."
    MetadataDates::Union{Nothing,Vector{DateType}}
    "Formerly called Internal Directory Name (IDN) Node (IDN_Node). This element has been used historically by the GCMD internally to identify association, responsibility and/or ownership of the dataset, service or supplemental information. Note: This field only occurs in the DIF. When a DIF record is retrieved in the ECHO10 or ISO 19115 formats, this element will not be translated. The controlled vocabulary for directory names is maintained in the Keyword Management System (KMS)."
    DirectoryNames::Union{Nothing,Vector{DirectoryNameType}}
    "This entity stores the reference frame or system from which horizontal and vertical spatial domains are measured. The horizontal reference frame includes a Geodetic Model, Geographic Coordinates, and Local Coordinates. The Vertical reference frame includes altitudes (elevations) and depths."
    SpatialInformation::Union{Nothing,SpatialInformationType}
    "The unique name."
    ShortName::String
    "Free-text description of the version of the resource such as a Collection."
    VersionDescription::Union{Nothing,String}
    "This element defines how the data may or may not be used after access is granted to assure the protection of privacy or intellectual property. This includes license text, license URL, or any special restrictions, legal prerequisites, terms and conditions, and/or limitations on using the data set. Data providers may request acknowledgement of the data from users and claim no responsibility for quality and completeness of data."
    UseConstraints::Union{Nothing,UseConstraintsType}
    "This element is reserved for NASA records only. A Standard Product is a product that has been vetted to ensure that they are complete, consistent, maintain integrity, and satifies the goals of the Earth Observing System mission. The NASA product owners have also commmitted to archiving and maintaining the data products. More information can be found here: https://earthdata.nasa.gov/eosdis/science-system-description/eosdis-standard-products."
    StandardProduct::Union{Nothing,Bool}
    "A brief description of the collection. This allows potential users to determine if the collection is useful for their needs."
    Abstract::String
    "This element stores the DOI (Digital Object Identifier) that identifies the collection. Note: The values should start with the directory indicator which in ESDIS' case is 10.  If the DOI was registered through ESDIS, the beginning of the string should be 10.5067. The DOI URL is not stored here; it should be stored as a RelatedURL. The DOI organization that is responsible for creating the DOI is described in the Authority element. For ESDIS records the value of https://doi.org/ should be used. For those that want to specify that a DOI is not applicable or unknown use the second option."
    DOI::DoiType
    "Identifies the topic categories from the EN ISO 19115-1:2014 Geographic Information – Metadata – Part 1: Fundamentals (http://www.isotc211.org/) Topic Category Code List that pertain to this collection, based on the Science Keywords associated with the collection. An ISO Topic Category is a high-level thematic classification to assist in the grouping of and search for available collections. The controlled vocabulary for ISO topic categories is maintained in the Keyword Management System (KMS)."
    ISOTopicCategories::Union{Nothing,Vector{String}}
end
StructTypes.StructType(::Type{UMM_C}) = StructTypes.Struct()


end
