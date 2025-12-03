Harris Central Appraisal District 

GIS PData Dictionary 

The HCAD GIS Shapeﬁles provided by the District are in Shapeﬁle or File Geodatabase 
format. These ﬁles can be opened with a variety of free or purchasable software from 
several vendors, with ESRI’s ArcGIS software being one such common program. ESRI 
offers a free viewer, ArcGIS Earth for Windows available here: https://www.esri.com/en-
us/arcgis/products/arcgis-earth/overview 

All Spatial Data provided by the Harris Central Appraisal District is projected in NAD83 
Texas State Plane South Central Zone (FIPS 4204) (US Feet). This projection can be 
additionally identiﬁed by its EPSG Code of 2278 or its WKID of 102740. For more on 
coordinate systems, this blog post provided by ESRI provides some additional 
information: https://www.esri.com/arcgis-blog/products/arcgis-
pro/mapping/coordinate-systems-difference/ 

Legal Disclaimer: Geospatial or map data maintained by the Harris Central Appraisal 
District is for informational purposes and may not have been  prepared for or be 
suitable for legal, engineering, or surveying purposes. It does not represent an on-the-
ground survey and only represents the approximate location of property boundaries. 

Announcements:  

****************************************************************************************** 

 The following is a complete list of shapeﬁles and ﬁle geodatabases maintained at 
https://hcad.org/pdata/pdata-gis-downloads.html  

Sources: 

https://www.hctax.net/Property/Resources 

The Structure of all data will follow the following format: 

 
 
 
 
 
 
 
Name Name of the Shapeﬁle or File Geodatabase 

  Field Name Field Name in Shapeﬁle or File Geodatabase 
o  Field Type Ex. Text, Integer, Length of Field 

  Description of Field Example of data (if applicable) 

Abstract 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Abstract_N 

o  Text (Length: 50) 

  Name of Abstract Example: W. C. RR. CO. SEC. 4 BLK. 5 

  Abstract_1 

o  Long (Integer) 

  Abstract Number Example: 761 This is the Abstract Number without 

the County preﬁx (Harris County is 201) 

  Volume 

o  Text (Length: 3) 

  Volume from Harris County Clerks Oﬃce Example: 045 
  Harris County Block Book Maps 

  Page 

o  Text (Length: 3) 

  Page from Harris County Clerks Oﬃce Example: 065 
  Harris County Block Book Maps 

  HcadGis_GI 

o  Double 

  Artifact from system migration to be removed in future updates 

  Hcadgis__1 

o  Double 

  Artifact from system migration to be remove in future updates 

  Area_1 

o  Double 

  Artifact from system migration to be remove in future updates 

  Len_1 

 
o  Double 

  Artifact from system migration to be remove in future updates 

  GlobalID 

o  Text (Length: 38) 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated area of a polygon represented in feet 

BLK_num 

  TEXTSTRING 

o  Text (Length: 255) 

  Subdivision number to help tract speciﬁc group of parcels aids 

legal descriptions/records 

  TEXTSTRING ﬁeld only attribute to contain any real data; all others 

are artifacts from system migration to be removed in future 
updates 

BLK_anno 

  TextString 

o  Text (Length: 255) 

  Subdivision number to help tract speciﬁc group of parcels, aids 

legal descriptions/records 

  TextString ﬁeld only attribute to contain real data; all others are 

artifacts from system migration to be removed in future updates 

  Annotation (anno) is a type of feature that consists of text with 

position, layout and style attributes 

City 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

 
 
o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

  Text (Length: 4) 
  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  EX: 061  

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction 
  EX: CITY OF HOUSTON 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in 

feet 

College 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

o  Text (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  Ex: 046 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction 
  EX: LEE JR COLLEGE DISTRICT 

 

 
 
  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet. 

 
  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

County 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

o  Text (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  Ex: 040 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction 
  Ex: Harris County 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet.   

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet   

Deﬁned_Area 
  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

 
 
 
 
  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

o  Text (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  Ex: 347 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction  
  NORTHAMPTON MUD DA 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet. 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet. 

Easement_line 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Name 

o  Text (Length: 50) 

  Name of the easement as maintained by HCAD which could be 
represented by the HCAD account number or deed number 

  Type_ 

o  Long Integer 

  Artifact from system migration to be removed in future updates 

  StatedArea 

o  Text (Length: 50) 

 
  Legal area provided on/from a legal document 

  Encumbrance 

o  Text (Length: 50) 
o  Ex: ROW Easement, Drainage Easement, Easement 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet. 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet. 

Easement_name 

  TextString 

o  Text (Length: 255) 

  Name of the easement as maintained by HCAD which could be 
represented by the HCAD account number or deed number 

  TextString ﬁeld only attribute to contain any real data; all others are 
artifacts from system migration to be removed in future updates 

Easement_anno 

  TextString 

o  Text (Length: 255) 

  Name of the easement as maintained by HCAD which could be 
represented by the HCAD account number or deed number 

  TextSring ﬁeld only migration to contain any real data; all others are 

artifacts from system to be removed in future updates 

  Annotation (anno) is a type of feature that consists of text with 

position, layout and style attributes 

Emergency 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

 
 
  Code 

o  Text (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  Ex: 676 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction  

  EX: HC ESD 06 (EMS) 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

Facet 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  QFNAME 

o  Text (Length: 5) 
o  Name of the quarter facet maintained by HCAD 
o  Ex: 5974B 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

Fire 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

o  Text (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  Ex: 636 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction  

  Ex: HC ESD 20 (FIRE) 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet. 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet. 

HWY *For visual reference only 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Hwy_Name 

o  Text (Length: 20) 
o 
 Highway number 
o  Ex: 45 

  Type 

o  Text (Length: 10) 

  Ex:  45 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

Lot 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Type_ 

o  Long Integer 

  EX. Right of way easement 
  Artifact from system migration to be removed in future updates 

  StatedArea 

o  Text (Length: 50) 

  Legal area provided on/from a legal document   

  SimConDivT 

o  Text (Length: 50) 
o  Lot or unit type                                                                                                     

  EX: Lot to be removed in future updates 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

Lot_num 

  TextString 

o  Text (Length: 255) 

  Speciﬁc number to indicate a particular parcel within a subdivision 
  TextString ﬁeld only attribute to contain real data; all others are 

artifacts from system to be removed in future updates 

Lot Annonation 

  TextString 

o  Text (Length: 255) 

 
 
 
  Speciﬁc number to indicate a particular parcel within a subdivision 
  TextString ﬁeld only attribute to contain rea datal all others are 

artifacts from system to be removed in future updates 

  Annotation (anno) is a type of feature that consists of text with 

position, layout and style attributes 

Parcels 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  LOWPARCELI 

o  Text (Length: 30) 
o  HCAD account number enumeration 
o  Account number that ties multiple accounts in a single polygon 

  HCAD_NUM 

o  Text (Length: 30) 
o  HCAD account number 

  CurrOwner 

o  Text (Length: 100) 

  Current Owner  

  LocAddr 

o  Text (Length: 97) 
o  Mailing address 

  LocNum 

o  Long Integer 
o  Site address number 
o  EX: 1234 

  LocName 

o  Text (Length: 50) 
o  Street or road name  
o  EX: Heights 

  City 

o  Text (Length: 50) 

  City whichparcel is located within 

 
  EX: Houston 

  Zip  

o  Text (Length: 10) 

  Zip code Parcel falls in 
  EX: 77008 

  Parcel_typ 

o  Long Integer 
o  Artifact from system migration to be removed in future updates 

  StatedArea 

o  Text (Length: 50) 

  Legal area provided on/from a legal document   

  Acreage 

o  Text (Length: 20) 

  Legal area provided on/from a legal document one acre or more 

provided 
  EX: 1.2345 AC 

  SiteNumber 

o  Text (Length: 10) 

  Unique identiﬁer assigned to a speciﬁc parcel 
  Site address number 
  EX: 1234 

  Stacked 

o  Long Integer 
o  Value indicating whether polygon contains multiple accounts 
o  EX: value of 1, two or more accounts present 

o 

o 

Mill_cd 

  Text (Length: 16) 

Mail_addr_ 

  Text (Length: 50) 

  Mailing address 

o 

Mail_city 

  Text (Length: 50) 

  City where property resides 

  EX: Houston 

o 

Mail_state 

 
 
  Text (Length: 2) 

  State where property resides 

  EX: TX 

o 

Mail_zip 

  Text (Length: 16) 

  Zip code where property resides Yr_impr 

  Long Integer 

ROW_Annonation 

  Text 

o  TextString (Length: 255) 

  ROW or right of way, name of a particular segment of road, allowing 

passage to another’s person’s land or property 

  TextString ﬁeld only attribute to contain any real data; all others are 
artifacts from system migration to be removed in future updates 

  Annotation (anno) is a type of feature that consists of text with position, 

layout and style attributes 

Row_Line 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Calculated 

o  Long Integer 

  Field indicating whether line feature used one ﬁeld to populate a 

different ﬁeld 

  ParcelID 

o  Long Integer 

  a unique identiﬁcation number assigned to a speciﬁc piece of land 
by a local government or assessor's oﬃce, used primarily for tax 

 
 
assessment purposes and to track ownership and location 
information of that property 

  System generated unique number assigned to every line feature 
  EX: 12345 

  Bearing 

o  Double 

  directional measurement, usually expressed as a compass bearing 
(like N 30° E), used to deﬁne the direction of a property boundary 
line on a parcel of land 

  Distance 

o  Text (Length: 20) 
o  Measure distance of line feature 

  Type 

o  Long Integer 

  Category 

o  Long Integer 

  Hide 

o  Long Integer 

  Dimension 

o  Text (Length: 20) 

  Represents the distance of the property line as shown in the legal document (ie 

deed or plat) which describes the property 

o  Long Integer 

  SHAPE_STLe 
o  Double 

  System generated perimeter of the polygon in feet 

School 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

o  Text (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

 
  Ex: 001 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction  
  Ex: HOUSTON ISD 

  GlobalID 

o  Text (Length: 38) 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

Special 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

o  ext (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  Ex: 850 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction  
  Ex: HARRIS COUNTY ID 3 

  GlobalID 

o  Text (Length: 38) 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

Subdivision 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Name 

o  Text (Length: 254) 

  Name of the subdivision 
  Ex: WILLIAMS ACRES 

  Type 

o  Long Integer 

  Artifact from system migration to be removed in future updates 

  Conveyance 

o  Text (Length: 50) 

  Sub_Name_F 

o  Text (Length: 250) 

  Full name of the subdivision 
  EX: HOUSTON INDEPENDENT SCHOOL DISTRICT FROST REPLACEMENT 

ELEMENTARY SCHOOL 

  Vol_Page 

o  Text (Length: 10) 

  Volume and page numbers maintained by HCAD 
  EX: 123-456 
  First three digits represent the Volume number, and the second three 

digits represent the Page number. These represent the ﬁrst six digits of a 
parcel number within a subdivision. 

  RECNUM 

o  Text (Length: 8) 

  Film code number referenced in survey plats to help identify subdivisions 
  EX: 123456 

  Deed_Num 

o  Text (Length: 50) 

  Legal document stating ownership of a property or transfer of asset 

  Beg_Page 

o  Text (Length: 4) 

 
  The ﬁrst page number assigned in the series for the subdivision 

  End_Page 

o  Text (Length: 4) 

  The last page number assigned in the series for the subdivision 

  Section 

o  Text (Length: 20) 

  A numbered area within a larger subdivision plan Tax_Year 

o  Long Integer 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

TIRZ 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

o  ext (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  Ex: 302 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction  
  Ex: TIRZ 2 MIDTOWN (048) 

  GlobalID 

o  Text (Length: 38) 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

Utility 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

o  ext (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  Ex: 225 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction  
  Ex: HARRIS COUNTY MUD 346 

  GlobalID 

o  Text (Length: 38) 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

Water_District 

  FID 

o  Object ID 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape 

o  Geometry 

  System generated ﬁeld for determining whether a record is a point, 

polyline, or polygon 

  Code 

o  ext (Length: 4) 

  Four-character alpha numeric code which represents a taxing 

jurisdiction maintained by HCAD 

  Ex: 628 

  Name 

o  Text (Length: 30) 

  Name of the taxing jurisdiction  
  Ex: HARRIS COUNTY WCID 132 

  GlobalID 

o  Text (Length: 38) 

  System generated ﬁeld for shapeﬁles to maintain data structure 

order 

  Shape_STAr 

o  Double 

  System generated area of a polygon represented in square feet 

  Shape_STLe 

o  Double 

  System generated perimeter of the polygon represented in feet 

