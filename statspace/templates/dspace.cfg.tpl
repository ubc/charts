{{- define "dspace.cfg" -}}
#
# DSpace Configuration
#
# NOTE: The DSpace Configuration File is separated into several sections:
#  * General Configurations
#  * JSPUI & XMLUI Configurations
#  * JSPUI Specific Configurations
#  * XMLUI Specific Configurations
#
# Revision: $Revision$
#
# Date:     $Date$
#


#------------------------------------------------------------------#
#------------------GENERAL CONFIGURATIONS--------------------------#
#------------------------------------------------------------------#
# These configs are used by underlying DSpace API, and are         #
# therefore applicable to all interfaces                           #
# Local, simple configuration should be made in build.properties   #
# Global or more complex configuration can be hardcoded here       #
#------------------------------------------------------------------#
##### Basic information ######

# DSpace installation directory
dspace.dir = /dspace

# DSpace host name - should match base URL.  Do not include port number.
{{- $hosts := append .Values.ingress.hosts .Values.CI_ENVIRONMENT_HOSTNAME | compact | uniq }}
dspace.hostname = {{ index $hosts 0 }}

# DSpace base host URL.  Include port number etc.
dspace.baseUrl = https://{{ index $hosts 0 }}

# DSpace base URL.  Include port number etc., but NOT trailing slash
# Change to xmlui if you wish to use the xmlui as the default, or remove
# "/jspui" and set webapp of your choice as the "ROOT" webapp in
# the servlet engine.
dspace.url = https://{{ index $hosts 0 }}

# Optional: DSpace URL for mobile access
# This
#dspace.mobileUrl = http://mobile.example.com

# Name of the site
dspace.name = {{ .Values.dspace.name }}

# Default language for metadata values
default.language = en_US

##### Database settings #####

# URL for connecting to database
db.url = jdbc:postgresql://{{ template "postgresql.fullname" . | default .Values.postgresql.service.name }}:{{ .Values.postgresql.service.port }}/{{ .Values.postgresql.postgresDatabase }}

# JDBC Driver
db.driver = org.postgresql.Driver

# Database username and password
db.username = {{ .Values.postgresql.dbUser }}
db.password = {{ .Values.postgresql.dbPassword }}

# Schema name - if your database contains multiple schemas, you can avoid
# problems with retrieving the definitions of duplicate object names by
# specifying the schema name that is used for DSpace.
# ORACLE USAGE NOTE: In Oracle, schema is equivalent to "username". This means
# specifying a "db.schema" is often unnecessary (i.e. you can leave it blank),
# UNLESS your Oracle DB Account (in db.username) has access to multiple schemas.
db.schema =

## Connection pool parameters

# Maximum number of DB connections in pool
db.maxconnections = 30

# Maximum time to wait before giving up if all connections in pool are busy (milliseconds)
db.maxwait = 5000

# Maximum number of idle connections in pool (-1 = unlimited)
db.maxidle = -1

# Determine if prepared statement should be cached. (default is true)
db.statementpool = true

# Specify a name for the connection pool (useful if you have multiple applications sharing Tomcat's dbcp)
# If not specified, defaults to 'dspacepool'
db.poolname = dspacepool

# Specify a configured database connection pool to be fetched from a
# directory.  This overrides the pool and driver settings above.  If
# none can be found, then DSpace will use the above settings to create a
# pool.
#db.jndi = jdbc/dspace

##### Email settings ######

# SMTP mail server
mail.server = {{ .Values.dspace.email.host }}

# SMTP mail server authentication username and password (if required)
mail.server.username = {{ .Values.dspace.email.username }}
mail.server.password = {{ .Values.dspace.email.password }}

# SMTP mail server alternate port (defaults to 25)
mail.server.port = {{ .Values.dspace.email.port }}

# From address for mail
mail.from.address = {{ .Values.dspace.email.from }}

# Name of a pre-configured Session object to be fetched from a directory.
# This overrides the Session settings above.  If none can be found, then DSpace
# will use the above settings to create a Session.
#mail.session.name = Session

# Currently limited to one recipient!
feedback.recipient = {{ .Values.dspace.email.feedback }}

# General site administration (Webmaster) e-mail
mail.admin = {{ .Values.dspace.email.admin }}

# Recipient for server errors and alerts
alert.recipient = {{ .Values.dspace.email.alert }}

# Recipient for new user registration emails
registration.notify = {{ .Values.dspace.email.registration }}

# Set the default mail character set. This may be overridden by providing a line
# inside the email template "charset: <encoding>", otherwise this default is used.
mail.charset = UTF-8

# A comma-separated list of hostnames that are allowed to refer browsers to email forms.
# Default behaviour is to accept referrals only from dspace.hostname
mail.allowed.referrers = localhost

# Pass extra settings to the Java mail library. Comma-separated, equals sign between
# the key and the value. For example:
#mail.extraproperties = mail.smtp.socketFactory.port=465, \
#                       mail.smtp.socketFactory.class=javax.net.ssl.SSLSocketFactory, \
#                       mail.smtp.socketFactory.fallback=false

# An option is added to disable the mailserver. By default, this property is set to false
# By setting mail.server.disabled = true, DSpace will not send out emails.
# It will instead log the subject of the email which should have been sent
# This is especially useful for development and test environments where production data is used when testing functionality.
#mail.server.disabled = false

##### File Storage ######

# Asset (bitstream) store number 0 (zero)
assetstore.dir = ${dspace.dir}/persistent/assetstore

# Specify extra asset stores like this, counting from 1 upwards:
# assetstore.dir.1 = /second/assetstore
# assetstore.dir.2 = /third/assetstore

# Specify the number of the store to use for new bitstreams with this property
# The default is 0 (zero) which corresponds to the 'assetstore.dir' above
# assetstore.incoming = 1


##### SRB File Storage #####

# The same 'assetstore.incoming' property is used to support the use of SRB
# (Storage Resource Broker - see http://www.sdsc.edu/srb/) as an _optional_
# replacement of or supplement to conventional file storage. DSpace will work
# with or without SRB and full backward compatibility is maintained.
#
# The 'assetstore.incoming' property is an integer that references where _new_
# bitstreams will be stored.  The default (say the starting reference) is zero.
# The value will be used to identify the storage where all new bitstreams will
# be stored until this number is changed.  This number is stored in the
# Bitstream table (store_number column) in the DSpace database, so older
# bitstreams that may have been stored when 'asset.incoming' had a different
# value can be found.
#
# In the simple case in which DSpace uses local (or mounted) storage the
# number can refer to different directories (or partitions).  This gives DSpace
# some level of scalability.  The number links to another set of properties
# 'assetstore.dir', 'assetstore.dir.1' (remember zero is default),
# 'assetstore.dir.2', etc., where the values are directories.
#
# To support the use of SRB DSpace uses this same scheme but broadened to
# support:
# - using SRB instead of the local filesystem
# - using the local filesystem (native DSpace)
# - using a mix of SRB and local filesystem
#
# In this broadened use the 'asset.incoming' integer will refer one of the
# following storage locations
# - a local filesystem directory (native DSpace)
# - a set of SRB account parameters (host, port, zone, domain, username,
#       password, home directory, and resource)
#
# Should there be any conflict, like '2' refering to a local directory and
# to a set of SRB parameters, the program will select the local directory.
#
# If SRB is chosen from the first install of DSpace, it is suggested that
# 'assetstore.dir' (no integer appended) be retained to reference a local
# directory (as above under File Storage) because build.xml uses this value
# to do a mkdir. In this case, 'assetstore.incoming' can be set to 1 (i.e.
# uncomment the line in File Storage above) and the 'assetstore.dir' will not
# be used.
#
# Here is an example set of SRB parameters:
# Assetstore 1 - SRB
#srb.host.1 = mysrbmcathost.myu.edu
#srb.port.1 = 5544
#srb.mcatzone.1 = mysrbzone
#srb.mdasdomainname.1 = mysrbdomain
#srb.defaultstorageresource.1 = mydefaultsrbresource
#srb.username.1 = mysrbuser
#srb.password.1 = mysrbpassword
#srb.homedirectory.1 = /mysrbzone/home/mysrbuser.mysrbdomain
#srb.parentdir.1 = mysrbdspaceassetstore
#
# Assetstore n, n+1, ...
# Follow same pattern as for assetstores above (local or SRB)


##### Logging configuration #####

# Override default log4j configuration
# You may provide your own configuration here, existing alternatives are:
# log.init.config = ${dspace.dir}/config/log4j.xml
# log.init.config = ${dspace.dir}/config/log4j-console.properties
log.init.config = ${dspace.dir}/config/log4j.properties

# Where to put the logs (used in configuration only)
log.dir = ${dspace.dir}/persistent/log

# If enabled, the logging and the Solr statistics system will look for
# an X-Forwarded-For header. If it finds it, it will use this for the user IP address
useProxies = true

##### DOI registration agency credentials ######
# To mint DOIs you have to use a DOI registration agency like DataCite. Several
# DataCite members offers services as DOI registration agency, so f.e. EZID or
# TIB Hannover. To mint DOIs with DSpace you have to get an agreement with an
# DOI registration agency. You have to edit
# [dspace]/config/spring/api/identifier-service.xml and to configure the following
# properties.

# Credentials used to authenticate against the registration agency:
identifier.doi.user = username
identifier.doi.password = password
# DOI prefix used to mint DOIs. All DOIs minted by DSpace will use this prefix.
# The Prefix will be assigned by the registration agency.
identifier.doi.prefix = 10.5072
# If you want to, you can further separate your namespace. Should all the
# suffixes of all DOIs minted by DSpace start with a special string to separate
# it from other services also minting DOIs under your prefix?
identifier.doi.namespaceseparator = dspace/

##### Plugin management #####

# Where to look for third-party plugin packages.  The value is a colon-separated
# list of filesystem directories and/or JAR files:  a Java class path.  Plugin
# classes not found in the usual places will be sought in these places last.  If
# unset, only the standard places will be searched.
#plugin.classpath = ${dspace.dir}/plugins/aPlugin.jar

##### Search settings #####

# Where to put search index files
search.dir = ${dspace.dir}/search

# Higher values of search.max-clauses will enable prefix searches to work on
# large repositories
search.max-clauses = 2048

# Which Lucene Analyzer implementation to use.  If this is omitted or
# commented out, the standard DSpace analyzer (designed for English)
# is used by default.

# Non-Stemming analyzer.  Does not "stem" words/terms. When using this analyzer,
# a search for "wellness" will always return items matching "wellness" and not "well".
# However, similarly a search for "experiments" will only return objects matching
# "experiments" and not "experiment" or "experimenting".
# search.analyzer = org.dspace.search.DSNonStemmingAnalyzer

# Chinese analyzer
# search.analyzer = org.apache.lucene.analysis.cn.ChineseAnalyzer

search.analyzer = org.dspace.search.DSAnalyzer

# Boolean search operator to use, current supported values are OR and AND
# If this config item is missing or commented out, OR is used
# AND requires all search terms to be present
# OR requires one or more search terms to be present
search.operator = OR

# Maximum number of terms indexed for a single field in Lucene.
# Default is 10,000 words - often not enough for full-text indexing.
# If you change this, you'll need to re-index for the change
# to take effect on previously added items.
# -1 = unlimited (Integer.MAX_VALUE)
search.maxfieldlength = 10000

##### Fields to Index for Search #####

# DC metadata elements.qualifiers to be indexed for search
# format: - search.index.[number] = [search field]:element.qualifier
#       - * used as wildcard
#	- inputform -> In case we have different input-forms for different repository supported locales (e.g input-forms_el.xml, input-forms_pt.xml etc). In this case, the
#		stored and the displayed value from all input-forms are indexed. If the stored value is not found in input-forms, it is indexed anyway.
#		e.g.:search.index.12 = language:dc.language:inputform
#
###      changing these will change your search results,     ###
###  but will NOT automatically change your search displays  ###

search.index.1 = author:dc.contributor.*
search.index.2 = author:dc.creator.*
search.index.3 = title:dc.title.*
search.index.4 = keyword:dc.subject.*
search.index.5 = abstract:dc.description.abstract
search.index.6 = author:dc.description.statementofresponsibility
search.index.7 = series:dc.relation.ispartofseries
search.index.8 = abstract:dc.description.tableofcontents
search.index.9 = mime:dc.format.mimetype
search.index.10 = sponsor:dc.description.sponsorship
search.index.11 = identifier:dc.identifier.*
search.index.12 = language:dc.language.iso

##### Handle settings ######

# Canonical Handle URL prefix
#
# By default, DSpace is configured to use http://hdl.handle.net/
# as the canonical URL prefix when generating dc.identifier.uri
# during submission, and in the 'identifier' displayed in JSPUI
# item record pages.
#
# If you do not subscribe to CNRI's handle service, you can change this
# to match the persistent URL service you use, or you can force DSpace
# to use your site's URL, eg.
#handle.canonical.prefix = https://localhost/handle/
#
# Note that this will not alter dc.identifer.uri metadata for existing
# items (only for subsequent submissions), but it will alter the URL
# in JSPUI's 'identifier' message on item record pages for existing items.
#
# If omitted, the canonical URL prefix will be http://hdl.handle.net/
handle.canonical.prefix = https://{{ index $hosts 0 }}/handle/

# CNRI Handle prefix
handle.prefix = 123456789

# Directory for installing Handle server files
handle.dir = ${dspace.dir}/handle-server

# List any additional prefixes that need to be managed by this handle server
# (as for examle handle prefix coming from old dspace repository merged in
# that repository)
# handle.additional.prefixes = prefix1[, prefix2]

# By default we hide the list handles method in the JSON endpoint as it could
# produce heavy load for large repository
# handle.hide.listhandles = false

##### Authorization system configuration - Delegate ADMIN #####

# COMMUNITY ADMIN configuration
# subcommunities and collections
#core.authorization.community-admin.create-subelement = true
#core.authorization.community-admin.delete-subelement = true
# his community
#core.authorization.community-admin.policies = true
#core.authorization.community-admin.admin-group = true
# collections in his community
#core.authorization.community-admin.collection.policies = true
#core.authorization.community-admin.collection.template-item = true
#core.authorization.community-admin.collection.submitters = true
#core.authorization.community-admin.collection.workflows = true
#core.authorization.community-admin.collection.admin-group = true
# item owned by collections in his community
#core.authorization.community-admin.item.delete = true
#core.authorization.community-admin.item.withdraw = true
#core.authorization.community-admin.item.reinstatiate = true
#core.authorization.community-admin.item.policies = true
# also bundle...
#core.authorization.community-admin.item.create-bitstream = true
#core.authorization.community-admin.item.delete-bitstream = true
#core.authorization.community-admin.item-admin.cc-license = true

# COLLECTION ADMIN
#core.authorization.collection-admin.policies = true
#core.authorization.collection-admin.template-item = true
#core.authorization.collection-admin.submitters = true
#core.authorization.collection-admin.workflows = true
#core.authorization.collection-admin.admin-group = true
# item owned by his collection
#core.authorization.collection-admin.item.delete = true
#core.authorization.collection-admin.item.withdraw = true
#core.authorization.collection-admin.item.reinstatiate = true
#core.authorization.collection-admin.item.policies = true
# also bundle...
#core.authorization.collection-admin.item.create-bitstream = true
#core.authorization.collection-admin.item.delete-bitstream = true
#core.authorization.collection-admin.item-admin.cc-license = true

# ITEM ADMIN
#core.authorization.item-admin.policies = true
# also bundle...
#core.authorization.item-admin.create-bitstream = true
#core.authorization.item-admin.delete-bitstream = true
#core.authorization.item-admin.cc-license = true


#### Restricted item visibilty settings ###
# By default RSS feeds, OAI-PMH and subscription emails will include ALL items
# regardless of permissions set on them.
#
# If you wish to only expose items through these channels where the ANONYMOUS
# user is granted READ permission, then set the following options to false
#
# Warning: In large repositories, setting harvest.includerestricted.oai to false may cause
# performance problems as all items will need to have their authorization permissions checked,
# but because DSpace has not implemented resumption tokens in ListIdentifiers, ALL items will
# need checking whenever a ListIdentifers request is made.
#
#harvest.includerestricted.rss = true
#harvest.includerestricted.oai = true
#harvest.includerestricted.subscription = true


#### Proxy Settings ######
# uncomment and specify both properties if proxy server required
# proxy server for external http requests - use regular hostname without port number
http.proxy.host =

# port number of proxy server
http.proxy.port =


#### Media Filter / Format Filter plugins (through PluginManager) ####
# Media/Format Filters help to full-text index content or
# perform automated format conversions

#Names of the enabled MediaFilter or FormatFilter plugins
filter.plugins = PDF Text Extractor, HTML Text Extractor, \
                 PowerPoint Text Extractor, \
                 Word Text Extractor, \
                 ImageMagick Image Thumbnail, ImageMagick PDF Thumbnail
# "JPEG Thumbnail" removed in favour of using ImageMagick

# [To enable Branded Preview]: uncomment and insert the following into the plugin list
#                Branded Preview JPEG, \

# [To enable ImageMagick Thumbnail]:
#    remove "JPEG Thumbnail" from the plugin list
#    uncomment and insert the following line into the plugin list
#                ImageMagick Image Thumbnail, ImageMagick PDF Thumbnail, \

#Assign 'human-understandable' names to each filter
plugin.named.org.dspace.app.mediafilter.FormatFilter = \
  org.dspace.app.mediafilter.PDFFilter = PDF Text Extractor, \
  org.dspace.app.mediafilter.HTMLFilter = HTML Text Extractor, \
  org.dspace.app.mediafilter.WordFilter = Word Text Extractor, \
  org.dspace.app.mediafilter.PowerPointFilter = PowerPoint Text Extractor, \
  org.dspace.app.mediafilter.JPEGFilter = JPEG Thumbnail, \
  org.dspace.app.mediafilter.BrandedPreviewJPEGFilter = Branded Preview JPEG, \
  org.dspace.app.mediafilter.ImageMagickImageThumbnailFilter = ImageMagick Image Thumbnail, \
  org.dspace.app.mediafilter.ImageMagickPdfThumbnailFilter = ImageMagick PDF Thumbnail

#Configure each filter's input format(s)
filter.org.dspace.app.mediafilter.PDFFilter.inputFormats = Adobe PDF
filter.org.dspace.app.mediafilter.HTMLFilter.inputFormats = HTML, Text
filter.org.dspace.app.mediafilter.WordFilter.inputFormats = Microsoft Word
filter.org.dspace.app.mediafilter.PowerPointFilter.inputFormats = Microsoft Powerpoint, Microsoft Powerpoint XML
filter.org.dspace.app.mediafilter.JPEGFilter.inputFormats = BMP, GIF, JPEG, image/png
filter.org.dspace.app.mediafilter.BrandedPreviewJPEGFilter.inputFormats = BMP, GIF, JPEG, image/png
filter.org.dspace.app.mediafilter.ImageMagickImageThumbnailFilter.inputFormats = BMP, GIF, image/png, JPG, TIFF, JPEG, JPEG 2000
filter.org.dspace.app.mediafilter.ImageMagickPdfThumbnailFilter.inputFormats = Adobe PDF

#Publicly accessible thumbnails of restricted content.
#List the MediaFilter name's that would get publicly accessible permissions
#Any media filters not listed will instead inherit the permissions of the parent bitstream
#filter.org.dspace.app.mediafilter.publicPermission = JPEGFilter, XPDF2Thumbnail

#Custom settings for PDFFilter
# If true, all PDF extractions are written to temp files as they are indexed...this
# is slower, but helps ensure that PDFBox software DSpace uses doesn't eat up
# all your memory
#pdffilter.largepdfs = true
# If true, PDFs which still result in an Out of Memory error from PDFBox
# are skipped over...these problematic PDFs will never be indexed until
# memory usage can be decreased in the PDFBox software
#pdffilter.skiponmemoryexception = true

# Custom settigns for ImageMagick Thumbnail Filters
# ImageMagick and GhostScript must be installed on the server, set the path to ImageMagick and GhostScript executable
#   http://www.imagemagick.org/
#   http://www.ghostscript.com/
# Note: thumbnail.maxwidth and thumbnail.maxheight are used to set Thumbnail dimensions
# org.dspace.app.mediafilter.ImageMagickThumbnailFilter.ProcessStarter = /usr/bin
#
# bitstreams generated by this process will contain the following description and may be overwritten
# org.dspace.app.mediafilter.ImageMagickThumbnailFilter.bitstreamDescription = IM Thumbnail
#
# bitstream descriptions that do not conform to the following regular expression will not be overwritten
# org.dspace.app.mediafilter.ImageMagickThumbnailFilter.replaceRegex = ^Generated Thumbnail$
# 
# While PDFs may contain transparent spaces, JPEG cannot. As DSpace use JPEG
# for the generated thumbnails, PDF containing transparent spaces may lead
# to problems. To solve this the exported PDF page is flatten before it is
# resized and stored as JPEG. You can switch this behavior off by setting the
# next property false, if necessary for any reasons.
# org.dspace.app.mediafilter.ImageMagickThumbnailFilter.flatten = true

# Optional: full paths to CMYK and sRGB color profiles. If present, will allow
# ImageMagick to produce much more color accurate thumbnails for PDFs that are
# using the CMYK color system. The default_cmyk.icc and default_rgb.icc profiles
# provided by the system's Ghostscript (version 9.x) package are good choices.
org.dspace.app.mediafilter.ImageMagickThumbnailFilter.cmyk_profile = /usr/share/ghostscript/9.06/iccprofiles/default_cmyk.icc
org.dspace.app.mediafilter.ImageMagickThumbnailFilter.srgb_profile = /usr/share/ghostscript/9.06/iccprofiles/default_rgb.icc

#### Crosswalk and Packager Plugin Settings ####
# Crosswalks are used to translate external metadata formats into DSpace's internal format (DIM)
# Packagers are used to ingest/export 'packages' (both content files and metadata)

# Configure table-driven MODS dissemination crosswalk
#  (add lower-case name for OAI-PMH)
crosswalk.mods.properties.MODS = crosswalks/mods.properties
crosswalk.mods.properties.mods = crosswalks/mods.properties

# Configure XSLT-driven submission crosswalk for MODS
crosswalk.submission.MODS.stylesheet= crosswalks/mods-submission.xsl

# Configure XSLT-driven submission crosswalk for EPDCX. Originally developed for use with SWORD.
crosswalk.submission.EPDCX.stylesheet = crosswalks/sword-swap-ingest.xsl

# Configure the QDCCrosswalk dissemination plugin for Qualified DC
#  (add lower-case name for OAI-PMH)
crosswalk.qdc.namespace.QDC.dc = http://purl.org/dc/elements/1.1/
crosswalk.qdc.namespace.QDC.dcterms = http://purl.org/dc/terms/
crosswalk.qdc.schemaLocation.QDC  = \
  http://purl.org/dc/terms/ http://dublincore.org/schemas/xmls/qdc/2006/01/06/dcterms.xsd \
  http://purl.org/dc/elements/1.1/ http://dublincore.org/schemas/xmls/qdc/2006/01/06/dc.xsd
crosswalk.qdc.properties.QDC = crosswalks/QDC.properties

crosswalk.qdc.namespace.qdc.dc = http://purl.org/dc/elements/1.1/
crosswalk.qdc.namespace.qdc.dcterms = http://purl.org/dc/terms/
crosswalk.qdc.schemaLocation.qdc  = \
  http://purl.org/dc/terms/ http://dublincore.org/schemas/xmls/qdc/2006/01/06/dcterms.xsd \
  http://purl.org/dc/elements/1.1/ http://dublincore.org/schemas/xmls/qdc/2006/01/06/dc.xsd
crosswalk.qdc.properties.qdc = crosswalks/QDC.properties

#### XSLTDisseminationCrosswalks ####
# XSLTDisseminationCrosswalks uses the selfnamed plugin
# org.dspace.content.crosswalk.XSLTDisseminationCrosswalk configured above.
# If you remove all XSLTDisseminationCrosswalk you should disable this plugin
# to avoid an error log message every time you load DSpace!
##
## Configure XSLT-driven submission crosswalk for MARC21
##
crosswalk.dissemination.marc.stylesheet = crosswalks/DIM2MARC21slim.xsl
crosswalk.dissemination.marc.schemaLocation = \
    http://www.loc.gov/MARC21/slim \
    http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd
crosswalk.dissemination.marc.preferList = true
##
## Configure XSLT-driven submission crosswalk for DataCite
##
crosswalk.dissemination.DataCite.stylesheet = crosswalks/DIM2DataCite.xsl
## For DataCite via EZID, comment above and uncomment this:
#crosswalk.dissemination.DataCite.stylesheet = crosswalks/DIM2EZID.xsl
crosswalk.dissemination.DataCite.schemaLocation = \
    http://datacite.org/schema/kernel-2.2 \
    http://schema.datacite.org/meta/kernel-2.2/metadata.xsd
crosswalk.dissemination.DataCite.preferList = false

# Crosswalk Plugin Configuration:
#   The purpose of Crosswalks is to translate an external metadata format to/from
#   the DSpace Internal Metadata format (DIM) or the DSpace Database.
#   Crosswalks are often used by one or more Packager plugins (see below).
plugin.named.org.dspace.content.crosswalk.IngestionCrosswalk = \
  org.dspace.content.crosswalk.AIPDIMCrosswalk = DIM, \
  org.dspace.content.crosswalk.AIPTechMDCrosswalk = AIP-TECHMD, \
  org.dspace.content.crosswalk.PREMISCrosswalk = PREMIS, \
  org.dspace.content.crosswalk.OREIngestionCrosswalk = ore, \
  org.dspace.content.crosswalk.NullIngestionCrosswalk = NIL, \
  org.dspace.content.crosswalk.OAIDCIngestionCrosswalk = dc, \
  org.dspace.content.crosswalk.DIMIngestionCrosswalk = dim, \
  org.dspace.content.crosswalk.METSRightsCrosswalk = METSRIGHTS, \
  org.dspace.content.crosswalk.RoleCrosswalk = DSPACE-ROLES

plugin.selfnamed.org.dspace.content.crosswalk.IngestionCrosswalk = \
  org.dspace.content.crosswalk.XSLTIngestionCrosswalk, \
  org.dspace.content.crosswalk.QDCCrosswalk

plugin.named.org.dspace.content.crosswalk.StreamIngestionCrosswalk = \
  org.dspace.content.crosswalk.NullStreamIngestionCrosswalk = NULLSTREAM, \
  org.dspace.content.crosswalk.CreativeCommonsRDFStreamIngestionCrosswalk = DSPACE_CCRDF, \
  org.dspace.content.crosswalk.LicenseStreamIngestionCrosswalk = DSPACE_DEPLICENSE

plugin.named.org.dspace.content.crosswalk.DisseminationCrosswalk = \
  org.dspace.content.crosswalk.AIPDIMCrosswalk = DIM, \
  org.dspace.content.crosswalk.AIPTechMDCrosswalk = AIP-TECHMD, \
  org.dspace.content.crosswalk.SimpleDCDisseminationCrosswalk = DC, \
  org.dspace.content.crosswalk.SimpleDCDisseminationCrosswalk = dc, \
  org.dspace.content.crosswalk.PREMISCrosswalk = PREMIS, \
  org.dspace.content.crosswalk.METSDisseminationCrosswalk = METS, \
  org.dspace.content.crosswalk.METSDisseminationCrosswalk = mets, \
  org.dspace.content.crosswalk.METSRightsCrosswalk = METSRIGHTS, \
  org.dspace.content.crosswalk.OREDisseminationCrosswalk = ore, \
  org.dspace.content.crosswalk.DIMDisseminationCrosswalk = dim, \
  org.dspace.content.crosswalk.RoleCrosswalk = DSPACE-ROLES


# regarding the XSLTDisseminationCrosswalk see the section were it is
# configured to avoid error logs! Disable it if you remove its configuration.
plugin.selfnamed.org.dspace.content.crosswalk.DisseminationCrosswalk = \
  org.dspace.content.crosswalk.MODSDisseminationCrosswalk , \
  org.dspace.content.crosswalk.QDCCrosswalk, \
  org.dspace.content.crosswalk.XHTMLHeadDisseminationCrosswalk, \
  org.dspace.content.crosswalk.XSLTDisseminationCrosswalk

plugin.named.org.dspace.content.crosswalk.StreamDisseminationCrosswalk = \
  org.dspace.content.crosswalk.CreativeCommonsRDFStreamDisseminationCrosswalk = DSPACE_CCRDF, \
  org.dspace.content.crosswalk.CreativeCommonsTextStreamDisseminationCrosswalk = DSPACE_CCTEXT, \
  org.dspace.content.crosswalk.LicenseStreamDisseminationCrosswalk = DSPACE_DEPLICENSE

# Packager Plugin Configuration:
#   Configures the ingest and dissemination packages that DSpace supports.
#   These Ingester and Disseminator classes support a specific package file format
#   (e.g. METS) which DSpace understands how to import/export.  Each Packager
#   plugin often will use one (or more) Crosswalk plugins to translate metadata (see above).
plugin.named.org.dspace.content.packager.PackageDisseminator = \
  org.dspace.content.packager.DSpaceAIPDisseminator = AIP, \
  org.dspace.content.packager.DSpaceMETSDisseminator = METS, \
  org.dspace.content.packager.RoleDisseminator = DSPACE-ROLES

# Do NOT cache AIP/METS Disseminator plugin instances, as their exported obj lists
# (in AbstractPackageDisseminator) need to be reset each time a new export occurs
plugin.reusable.org.dspace.content.packager.DSpaceAIPDisseminator = false
plugin.reusable.org.dspace.content.packager.DSpaceMETSDisseminator = false

plugin.named.org.dspace.content.packager.PackageIngester = \
  org.dspace.content.packager.DSpaceAIPIngester = AIP, \
  org.dspace.content.packager.PDFPackager  = Adobe PDF, PDF, \
  org.dspace.content.packager.DSpaceMETSIngester = METS, \
  org.dspace.content.packager.RoleIngester = DSPACE-ROLES

# Do NOT cache AIP/METS Ingester plugin instances, as their imported obj lists
# (in AbstractPackageIngester) need to be reset each time a new import occurs
plugin.reusable.org.dspace.content.packager.DSpaceAIPIngester = false
plugin.reusable.org.dspace.content.packager.DSpaceMETSIngester = false

#### METS ingester configuration:
# These settings configure how DSpace will ingest a METS-based package

# Configures the METS-specific package ingesters (defined above)
# 'default' settings are specified by 'default' key

# Default Option to save METS manifest in the item: (default is false)
mets.default.ingest.preserveManifest = false

# Default Option to make use of collection templates when using the METS ingester (default is false)
mets.default.ingest.useCollectionTemplate = false

# Default crosswalk mappings
# Maps a METS 'mdtype' value to a DSpace crosswalk for processing.
# When the 'mdtype' value is same as the name of a crosswalk, that crosswalk
# will be called automatically (e.g. mdtype='PREMIS' calls the crosswalk named
# 'PREMIS', unless specified differently in below mapping)
# Format is 'mets.default.ingest.crosswalk.<mdType> = <DSpace-crosswalk-name>'
mets.default.ingest.crosswalk.DC = QDC
mets.default.ingest.crosswalk.DSpaceDepositLicense = DSPACE_DEPLICENSE
mets.default.ingest.crosswalk.Creative\ Commons = DSPACE_CCRDF
mets.default.ingest.crosswalk.CreativeCommonsRDF = DSPACE_CCRDF
mets.default.ingest.crosswalk.CreativeCommonsText = NULLSTREAM
mets.default.ingest.crosswalk.EPDCX = EPDCX

# Locally cached copies of METS schema documents to save time on ingest.  This
# will often speed up validation & ingest significantly.  Before enabling
# these settings, you must manually cache all METS schemas in
# [dspace]/config/schemas/ (does not exist by default).  Most schema documents
# can be found on the http://www.loc.gov/ website.
# Enable the below settings to pull these *.xsd files from your local cache.
# (Setting format: mets.xsd.<abbreviation> = <namespace> <local-file-name>)
#mets.xsd.mets = http://www.loc.gov/METS/ mets.xsd
#mets.xsd.xlink = http://www.w3.org/1999/xlink xlink.xsd
#mets.xsd.mods = http://www.loc.gov/mods/v3 mods.xsd
#mets.xsd.xml = http://www.w3.org/XML/1998/namespace xml.xsd
#mets.xsd.dc = http://purl.org/dc/elements/1.1/ dc.xsd
#mets.xsd.dcterms = http://purl.org/dc/terms/ dcterms.xsd
#mets.xsd.premis = http://www.loc.gov/standards/premis PREMIS.xsd
#mets.xsd.premisObject = http://www.loc.gov/standards/premis PREMIS-Object.xsd
#mets.xsd.premisEvent = http://www.loc.gov/standards/premis PREMIS-Event.xsd
#mets.xsd.premisAgent = http://www.loc.gov/standards/premis PREMIS-Agent.xsd
#mets.xsd.premisRights = http://www.loc.gov/standards/premis PREMIS-Rights.xsd

#### AIP Ingester & Disseminator Configuration
# These settings configure how DSpace will ingest/export its own
# AIP (Archival Information Package) format for backups and restores
# (Please note, as the DSpace AIP format is also METS based, it will also
# use many of the 'METS ingester configuration' settings directly above)

# AIP-specific ingestion crosswalk mappings
# (overrides 'mets.default.ingest.crosswalk' settings)
# Format is 'mets.dspaceAIP.ingest.crosswalk.<mdType> = <DSpace-crosswalk-name>'
mets.dspaceAIP.ingest.crosswalk.DSpaceDepositLicense = NULLSTREAM
mets.dspaceAIP.ingest.crosswalk.CreativeCommonsRDF = NULLSTREAM
mets.dspaceAIP.ingest.crosswalk.CreativeCommonsText = NULLSTREAM

# Create EPerson if necessary for Submitter when ingesting AIP (default=false)
# (by default, EPerson creation is already handled by 'DSPACE-ROLES' Crosswalk)
#mets.dspaceAIP.ingest.createSubmitter = false

## AIP-specific Disseminator settings
# These settings allow you to customize which metadata formats are exported in AIPs

# Technical metadata in AIP (exported to METS <techMD> section)
# Format is <label-for-METS>:<DSpace-crosswalk-name> [, ...] (label is optional)
# If unspecfied, defaults to "PREMIS"
aip.disseminate.techMD = PREMIS, DSPACE-ROLES

# Source metadata in AIP (exported to METS <sourceMD> section)
# Format is <label-for-METS>:<DSpace-crosswalk-name> [, ...] (label is optional)
# If unspecfied, defaults to "AIP-TECHMD"
aip.disseminate.sourceMD = AIP-TECHMD

# Preservation metadata in AIP (exported to METS <digipovMD> section)
# Format is <label-for-METS>:<DSpace-crosswalk-name> [, ...] (label is optional)
# If unspecified, defaults to nothing in <digiprovMD> section
#aip.disseminate.digiprovMD =

# Rights metadata in AIP (exported to METS <rightsMD> section)
# Format is <label-for-METS>:<DSpace-crosswalk-name> [, ...] (label is optional)
# If unspecified, default to adding all Licenses (CC and Deposit licenses),
# as well as METSRights information
aip.disseminate.rightsMD = DSpaceDepositLicense:DSPACE_DEPLICENSE, \
    CreativeCommonsRDF:DSPACE_CCRDF, CreativeCommonsText:DSPACE_CCTEXT, METSRIGHTS

# Descriptive metadata in AIP (exported to METS <dmdSec> section)
# Format is <label-for-METS>:<DSpace-crosswalk-name> [, ...] (label is optional)
# If unspecfied, defaults to "MODS, DIM"
aip.disseminate.dmd = MODS, DIM


#### Event System Configuration ####

# default synchronous dispatcher (same behavior as traditional DSpace)
event.dispatcher.default.class = org.dspace.event.BasicDispatcher

#
# uncomment below and comment out original property to enable the legacy lucene indexing
# event.dispatcher.default.consumers = versioning, search, browse, eperson, harvester
#
# add the browse consumer if you want to switch back to the DBMS Browse DAOs implementation
# as the SOLR implementation rely on the discovery consumer
#
# event.dispatcher.default.consumers = versioning, browse, discovery, eperson, harvester
#
# Add doi here if you are using org.dspace.identifier.DOIIdentifierProvider to generate DOIs.
# Adding doi here makes DSpace send metadata updates to your doi registration agency.
# Add rdf here, if you are using dspace-rdf to export your repository content as RDF.
event.dispatcher.default.consumers = versioning, discovery, eperson, harvester

# The noindex dispatcher will not create search or browse indexes (useful for batch item imports)
event.dispatcher.noindex.class = org.dspace.event.BasicDispatcher
event.dispatcher.noindex.consumers = eperson

# consumer to maintain the search index
event.consumer.search.class = org.dspace.search.SearchConsumer
event.consumer.search.filters = Community|Collection|Item|Bundle+Add|Create|Modify|Modify_Metadata|Delete|Remove

# consumer to maintain the discovery index
event.consumer.discovery.class = org.dspace.discovery.IndexEventConsumer
event.consumer.discovery.filters = Community|Collection|Item|Bundle+Add|Create|Modify|Modify_Metadata|Delete|Remove

# consumer to maintain the browse index
event.consumer.browse.class = org.dspace.browse.BrowseConsumer
event.consumer.browse.filters = Community|Collection|Item|Bundle+Add|Create|Modify|Modify_Metadata|Delete|Remove

# consumer related to EPerson changes
event.consumer.eperson.class = org.dspace.eperson.EPersonConsumer
event.consumer.eperson.filters = EPerson+Create

# consumer to clean up harvesting data
event.consumer.harvester.class = org.dspace.harvest.HarvestConsumer
event.consumer.harvester.filters = Item+Delete

# consumer to update metadata of DOIs
event.consumer.doi.class = org.dspace.identifier.doi.DOIConsumer
event.consumer.doi.filters = Item+Modify_Metadata

# consumer to update the triplestore of dspace-rdf
event.consumer.rdf.class = org.dspace.rdf.RDFConsumer
event.consumer.rdf.filters = Community|Collection|Item|Bundle|Bitstream|Site+Add|Create|Modify|Modify_Metadata|Delete|Remove

# test consumer for debugging and monitoring
#event.consumer.test.class = org.dspace.event.TestConsumer
#event.consumer.test.filters = All+All

# consumer to maintain versions
event.consumer.versioning.class = org.dspace.versioning.VersioningConsumer
event.consumer.versioning.filters = Item+Install

# authority consumer
event.consumer.authority.class = org.dspace.authority.indexer.AuthorityConsumer
event.consumer.authority.filters = Item+Modify|Modify_Metadata

# ...set to true to enable testConsumer messages to standard output
#testConsumer.verbose = true

#### Embargo Settings ####
# DC metadata field to hold the user-supplied embargo terms
embargo.field.terms = SCHEMA.ELEMENT.QUALIFIER

# DC metadata field to hold computed "lift date" of embargo
embargo.field.lift = SCHEMA.ELEMENT.QUALIFIER

# string in terms field to indicate indefinite embargo
embargo.terms.open = forever

# implementation of embargo setter plugin - replace with local implementation if applicable
plugin.single.org.dspace.embargo.EmbargoSetter = org.dspace.embargo.DefaultEmbargoSetter

# implementation of embargo lifter plugin - - replace with local implementation if applicable
plugin.single.org.dspace.embargo.EmbargoLifter = org.dspace.embargo.DefaultEmbargoLifter

#### Checksum Checker Settings ####
# Default dispatcher in case none specified
plugin.single.org.dspace.checker.BitstreamDispatcher=org.dspace.checker.SimpleDispatcher

# check history retention
checker.retention.default=10y
checker.retention.CHECKSUM_MATCH=8w


### Item export and download settings ###
# The directory where the exports will be done and compressed
org.dspace.app.itemexport.work.dir = ${dspace.dir}/persistent/exports

# The directory where the compressed files will reside and be read by the downloader
org.dspace.app.itemexport.download.dir = ${dspace.dir}/persistent/exports/download

# The length of time in hours each archive should live for. When new archives are
# created this entry is used to delete old ones
org.dspace.app.itemexport.life.span.hours = 48

# The maximum size in Megabytes the export should be.  This is enforced before the
# compression.  Each bitstream's size in each item being exported is added up, if their
# cummulative sizes are more than this entry the export is not kicked off
org.dspace.app.itemexport.max.size = 200

### Batch Item import settings ###
# The directory where the results of imports will be placed (mapfile, upload file)
org.dspace.app.batchitemimport.work.dir = ${dspace.dir}/persistent/imports

# Enable performance optimization for select-collection-step collection query
# Enable when having 
# a large number of collections and no Shibboleth or LDAP authentication.
# default = false, (disabled)
#org.dspace.content.Collection.findAuthorizedPerformanceOptimize = true

# For backwards compatibility, the subscription emails by default include any modified items
# uncomment the following entry for only new items to be emailed
# eperson.subscription.onlynew = true


# Identifier providers.
# Following are configuration values for the EZID DOI provider, with appropriate
# values for testing.  Replace the values with your assigned "shoulder" and
# credentials.
#identifier.doi.ezid.shoulder = 10.5072/FK2/
#identifier.doi.ezid.user = apitest
#identifier.doi.ezid.password = apitest
# A default publisher, for Items not previously published.
# (If generateDataciteXML bean property is enabled. Set default publisher in the
# XSL file configured by: crosswalk.dissemination.DataCite.stylesheet file.)
#identifier.doi.ezid.publisher = a publisher


#---------------------------------------------------------------#
#--------------JSPUI & XMLUI CONFIGURATIONS---------------------#
#---------------------------------------------------------------#
# These configs are used by both JSP and XML User Interfaces,   #
# except where explicitly stated otherwise.                     #
#---------------------------------------------------------------#

# Determine if super administrators (those whom are in the Administrators group)
# can login as another user from the "edit eperson" page. This is useful for
# debugging problems in a running dspace instance, especially in the workflow
# process. The default value is false, i.e. no one may assume the login of another user.
webui.user.assumelogin = true

# whether to display the contents of the licence bundle (often just the deposit
# licence in standard DSpace installation
webui.licence_bundle.show = false

##### Hide Item Metadata Fields  #####
# Fields named here are hidden in the following places UNLESS the
# logged-in user is an Administrator:
#  1. XMLUI metadata XML view, and Item splash pages (long and short views).
#  2. JSPUI Item splash pages
# To designate a field as hidden, add a property here in the form:
#    metadata.hide.SCHEMA.ELEMENT.QUALIFIER = true
#
# This default configuration hides the dc.description.provenance field,
# since that usually contains email addresses which ought to be kept
# private and is mainly of interest to administrators:
metadata.hide.dc.description.provenance = true

##### Settings for Submission Process #####

# Should the submit UI block submissions marked as theses?
webui.submit.blocktheses = false

# Whether or not we REQUIRE that a file be uploaded
# during the 'Upload' step in the submission process
# Defaults to true; If set to 'false', submitter has option to skip upload
#webui.submit.upload.required = true

# If the browser supports it, JSPUI uses html5 File API to enhance file upload.
# If this property is set to false the enhanced file upload is not used even
# if the browser would support it.
#webui.submit.upload.html5 = true

# Whether or not to use the 'advanced' form of the access step.
# Defaults to false, ie the simple form is used.
#webui.submission.restrictstep.enableAdvancedForm = false

# Special Group for UI: all the groups nested inside this group
# will be loaded in the multiple select list of the RestrictStep
#webui.submission.restrictstep.groups = SubmissionAdmin

#### Creative Commons settings ######

# The url to the web service API
cc.api.rooturl = http://api.creativecommons.org/rest/1.5

# Metadata field to hold CC license URI of selected license
# NB: DSpace (both JSPUI and XMLUI) presentation code expects 'dc.rights.uri' to hold CC data. If you change
# this to another field, please consult documentation on how to update UI configuration 
cc.license.uri = dc.rights.uri

# Metadata field to hold CC license name of selected license (if defined)
# NB: DSpace (both JSPUI and XMLUI) presentation code expects 'dc.rights' to hold CC data. If you change
# this to another field, please consult documentation on how to update UI configuration
cc.license.name = dc.rights

# Assign license name during web submission
cc.submit.setname = true

# Store license bitstream (RDF license text) during web submission
cc.submit.addbitstream = true

# ONLY JSPUI, enable Creative Commons admin 
webui.submit.enable-cc = false

# A list of license classes that should be excluded from selection process
# class names - comma-separated list -  must exactly match what service returns.
# At time of implementation, these are:
# publicdomain - "Public Domain"
# standard - "Creative Commons"
# recombo - "Sampling"
# zero - "CC0"
# mark - "Public Domain Mark"
cc.license.classfilter = recombo, mark

# Jurisdiction of the creative commons license -- is it ported or not?
# Use the key from the url seen in the response from the api call,
# http://api.creativecommons.org/rest/1.5/support/jurisdictions
# Commented out means the license is unported.
# (e.g. nz = New Zealand, uk = England and Wales, jp = Japan)
cc.license.jurisdiction = us

# Locale for CC dialogs
# A locale in the form language or language-country.
# If no default locale is defined the CC default locale will be used
cc.license.locale = en


##### Settings for Thumbnail creation #####

# whether to display thumbnails on browse and search results pages (1.2+)
# If you have customised the Browse columnlist, then you must also
# include a 'thumbnail' column in your configuration (1.5+)
# (This configuration is not used by XMLUI.  To show thumbnails in the
#  XMLUI, you just need to create a theme which displays them)
webui.browse.thumbnail.show = false

# max dimensions of the browse/search thumbs. Must be <= thumbnail.maxwidth
# and thumbnail.maxheight. Only need to be set if required to be smaller than
# dimension of thumbnails generated by mediafilter (1.2+)
#webui.browse.thumbnail.maxheight = 80
#webui.browse.thumbnail.maxwidth = 80

# whether to display the thumb against each bitstream (1.2+)
# (This configuration is not used by XMLUI.  To show thumbnails in the
#  XMLUI, you just need to create a theme which displays them)
webui.item.thumbnail.show = true

# where should clicking on a thumbnail from browse/search take the user
# Only values currently supported are "item" and "bitstream"
#webui.browse.thumbnail.linkbehaviour = item

# maximum width and height of generated thumbnails
thumbnail.maxwidth  = 300
thumbnail.maxheight = 300

# Blur before scaling.  A little blur before scaling does wonders for keeping
# moire in check.
thumbnail.blurring = true

# High quality scaling option.  Setting to true can dramatically increase
# image quality, but it takes longer to create thumbnails.
thumbnail.hqscaling = true


#### Settings for Item Preview ####

webui.preview.enabled = false
# max dimensions of the preview image
webui.preview.maxwidth = 600
webui.preview.maxheight = 600

# Blur before scaling.  A little blur before scaling does wonders for keeping
# moire in check.
webui.preview.blurring = true

# High quality scaling option.  Setting to true can dramatically increase
# image quality, but it will take much longer to create previews.
webui.preview.hqscaling = true

# the brand text
webui.preview.brand = My Institution Name

# an abbreviated form of the above text, this will be used
# when the preview image cannot fit the normal text
webui.preview.brand.abbrev = MyOrg

# the height of the brand
webui.preview.brand.height = 20

# font settings for the brand text
webui.preview.brand.font = SansSerif
webui.preview.brand.fontpoint = 12
#webui.preview.dc = rights


##### Settings for item count (strength) information ####

# whether to display collection and community strengths
# (Since DSpace 4.0, this config option is used by XMLUI, too.
# XMLUI only makes strengths available to themes if this is set to true!
# To show strengths in the XMLUI, you also need to create a theme which displays them)
webui.strengths.show = false

# if showing strengths, should they be counted in real time or
# fetched from cache?
#
# Counts fetched in real time will perform an actual count of the
# database contents every time a page with this feature is requested,
# which will not scale.  The default behaviour is to use a cache (see
# ItemCounter configuration)
#
# The default is to use a cache
#
# webui.strengths.cache = true


###### ItemCounter Configuration ######
#
# Define the DAO class to use. This must correspond to your choice of
# storage for the browse system (RDBMS: PostgreSQL or Oracle, Solr).
# By default, since DSpace 4.0, the Solr implementation is used.
#
# Only if you use a DBMS implementation and want to use the cache
# (recommended!), you must run the following command periodically
# to update the count:
#
# [dspace]/bin/itemcounter	(NOT required if you use the Solr implementation)
#
#
# PostgreSQL:
# ItemCountDAO.class = org.dspace.browse.ItemCountDAOPostgres
#
# Oracle:
# ItemCountDAO.class = org.dspace.browse.ItemCountDAOOracle
#
# Solr:
# ItemCountDAO.class = org.dspace.browse.ItemCountDAOSolr


###### Browse Configuration ######
#
# Define the DAO class to use this must meet your storage choice for
# the browse system (RDBMS: PostgreSQL or Oracle, Solr).
# By default, since DSpace 4.0, the Solr implementation is used
#
# PostgreSQL:
# browseDAO.class = org.dspace.browse.BrowseDAOPostgres
# browseCreateDAO.class = org.dspace.browse.BrowseCreateDAOPostgres
#
# Oracle:
# browseDAO.class = org.dspace.browse.BrowseDAOOracle
# browseCreateDAO.class = org.dspace.browse.BrowseCreateDAOOracle
#
# Solr:
# browseDAO.class = org.dspace.browse.SolrBrowseDAO
# browseCreateDAO.class = org.dspace.browse.SolrBrowseCreateDAO



#
# Use this to configure the browse indices. Each entry will receive a link in the
# navigation. Each entry can be configured in one of two ways. The first is:
#
# webui.browse.index.<n> = <index name> : metadata : \
#                                                       <schema prefix>.<element>[.<qualifier>|.*] : \
#                                                       (date | title | text) : (asc | desc)
#
# This form represent a unique index of metadata values from the item.
#
# (date | title | text | <other>) refers to the datatype of the field.
#                       date: the index type will be treated as a date object
#                       title: the index type will be treated like a title, which will include
#                                       a link to the item page
#                       text: the index type will be treated as plain text.  If single mode is
#                                       specified then this will link to the full mode list
#           <other>: any other datatype will be treated the same as 'text', although
#                   it will apply any custom ordering normalisation configured below
#
#   The final part of the configuration is optional, and specifies the default ordering
#   for the index - whether it is ASCending (the default, and best for text indexes), or
#   DESCending (useful for dates - ie. most recent submissions)
#
#   NOTE: the text to render the index will use the <index name> parameter to select
#   the message key from Messages.properties using a key of the form:
#
# browse.type.metadata.<index name>
#
# The other form is for indexes of the items themselves, ie. each entry will be displayed
# according to the configuration of by webui.itemlist.columns:
#
# webui.browse.index.<n> = <index name> : item : <sort option name> : (asc | desc)
#
# sort option name: this is the sorting to be applied to the display. It must match the
#                   name given to one of the webui.itemlist.sort-option entries given below.
#
#   The final part of the configuration is optional, and specifies the default ordering
#   for the index - whether it is ASCending (the default, and best for text indexes), or
#   DESCending (useful for dates - ie. most recent submissions)

#   NOTE: the text to render the index will use the <sort option name> parameter to select
#   the message key from Messages.properties (for JSPUI) using a key of the form:
#
# browse.type.item.<sort option name>
#
# Note: the index numbers <n> must start from 1 and increment continuously by 1
# thereafter.  Deviation from this will cause an error during install or
# configuration update
#
# For compatibility with previous versions:
#
webui.browse.index.1 = dateissued:item:dateissued
webui.browse.index.2 = author:metadata:dc.contributor.*,dc.creator:text
webui.browse.index.3 = title:item:title
webui.browse.index.4 = subject:metadata:dc.subject.*:text
#webui.browse.index.5 = dateaccessioned:item:dateaccessioned

## example of authority-controlled browse category - see authority control config
#webui.browse.index.5 = lcAuthor:metadataAuthority:dc.contributor.author:authority

# Enable/Disable tag cloud in browsing.
# webui.browse.index.tagcloud.<n> = true | false
# where n is the index number from the above options
# Default value is false. If no option exists for a specific index, it is assumed to be false.
# Changes to this option do NOT require re-indexing of discovery.
#
#webui.browse.index.tagcloud.4 = true

# Set the options for what can be sorted by
#
# Sort options will be available when browsing a list of items (i.e. an 'item' browse,
# or search results).  You can define an arbitrary number of fields
# to sort on, irrespective of which fields you display using webui.itemlist.columns
#
# the format is:
#
# webui.itemlist.sort-option.<n> = <option name> : \
#                                                                       <schema prefix>.<element>[.<qualifier>|.*] : \
#                                                                       (date | text | ...) : (show | hide)
#
# This is defined much the same as above.  The parameter after the metadata
# just lets the sorter know which normalisation to use - standard normalisations are title,
# text or date - however additional normalisations can be defined using the PluginManager.
#
# The final parts of the configuration is optional -  whether to SHOW (the default) or
# HIDE the option from the sorting controls in the user interface. This can be useful if
# you need to define a specific date sort for use by the recent items lists,
# but otherwise don't want users to choose that option.
#
webui.itemlist.sort-option.1 = title:dc.title:title
webui.itemlist.sort-option.2 = dateissued:dc.date.issued:date
webui.itemlist.sort-option.3 = dateaccessioned:dc.date.accessioned:date

# By default, the display of metadata in the browse indexes is case sensitive
# So, you will get separate entries for the terms
#
#   Olive oil
#   olive oil
#
# However, clicking through from either of these will result in the same set of items
# (ie. any item that contains either representation in the correct field).
#
# Uncommenting the option below will make the metadata items case-insensitive. This will
# result in a single entry in the example above. However the value displayed may be either 'Olive oil'
# or 'olive oil' - depending on what representation was present in the first item indexed.
#
# If you care about the display of the metadata in the browse index - well, you'll have to go and
# fix the metadata in your items.
#
# webui.browse.metadata.case-insensitive = true

# Set the options for the size (number of characters) of the fields stored in the database.
#
# The default is 0, which is unlimited size for fields holding indexed data.  Some
# database implementations (e.g. Oracle) will enforce their own limit on this field
# size. Reducing the field size will decrease the potential size of your database and
# increase the speed of the browse, but it will also increase the chance of
# mis-ordering of similar fields.  Below are commented out, but proposed values for
# reasonably performance versus result quality
#
# Size of field for the browse value (this will affect display, and value sorting)
#
# webui.browse.value_columns.max = 500

# Size of field for hidden sort columns (this will affect only sorting, not display)
#
# webui.browse.sort_columns.max = 200

# Omission mark to place after truncated strings in display.  The default is "..."
#
# webui.browse.value_columns.omission_mark = ...

# Set the options for how the indexes are sorted
#
# All sorts of normalisations are carried out by the OrderFormatDelegate.
# The plugin manager can be used to specify your own delegates for each datatype.
#
# The default datatypes (and delegates) are:
#
# author = org.dspace.sort.OrderFormatAuthor
# title  = org.dspace.sort.OrderFormatTitle
# text   = org.dspace.sort.OrderFormatText
#
# If you redefine a default datatype here, the configuration will be used in preference
# to the default, however, if you do not explicitly redefine a datatype, then the
# default will still be used in addition to the datatypes you do specify.
#
# As of 1.5.2, the multi-lingual MARC 21 title ordering is configured as default.
# To use the previous title ordering, comment out the configuration below

plugin.named.org.dspace.sort.OrderFormatDelegate= \
        org.dspace.sort.OrderFormatTitleMarc21=title

## Set the options for how authors are displayed in the browse listing

# Define which field is the author/editor etc listing.  This should be listed in the
# field webui.itemlist.columns, otherwise it will have no effect.
# This cannot be a field already marked out as a title or a date, as this
# will also have no effect.  This is used in conjunction with the
# webui.browse.author-limit field below, to truncate author lists.  For
# configuring links to author publication lists use webui.browse.link below.
# (This setting is not used by the XMLUI as it is controlled by your theme)
#
# webui.browse.author-field = dc.contributor.*

# define how many authors to display before truncating and completing with "et al"
# (or language pack specific alternative)
#
# Use -1 for unlimited (which is what will be used if this option
# is omitted)
#
# webui.browse.author-limit = 3

# which fields should link to other browse listings.  This should associated
# the name of one of the above browse indices with a metadata field listed
# in <webui.itemlist.columns> above.  The form is:
#
# webui.browse.link.<n> = <index name>:<display column metadata>
#
# Note that cross linking will only work for fields other than title.
#
# The effect this has is to create links to browse views for the item clicked on.
# If it is a "single" type, it will link to a view of all the items which share
# that metadata element in common (i.e. all the papers by a single author).  If
# it is a "full" type, it will link to a view of the standard full browse page,
# starting with the value of the link clicked on.
# (This setting is not used by the XMLUI, as links are controlled by your theme)
#
# The default below defines the authors to link to other publications by that author
#
webui.browse.link.1 = author:dc.contributor.*

### Render scientific formulas symbols in view/browse
# Use MathJax to render properly encoded text formulas to be visual for people
#webui.browse.render-scientific-formulas = true

#### Display browse frequencies
#
# webui.browse.metadata.show-freq.<n> = true | false
# where n is the same index as in webui.browse.index.<n> configurations
#
# For the browse indexes that this property is omitted, it is assumed as true
# please note that only a few overhead is required to compute frequencies when
# DBMS BrowseDAO is used and not overhead at all when SOLRBrowseDAO is used
# webui.browse.metadata.show-freq.1 = false
# webui.browse.metadata.show-freq.2 = false
# webui.browse.metadata.show-freq.3 = false
# webui.browse.metadata.show-freq.4 = true

#### Additional configuration for Recent Submissions code ####

# the sort option name (from webui.itemlist.sort-option above) to use for
# displaying recent submissions.  (this
# is used by the Recent Submissions system and any other time based
# browse query such as FeedServlet)
#
recent.submissions.sort-option = dateaccessioned

# how many recent submissions should be displayed at any one time
# Set to 0 since discovery uses a separate configuration for this
recent.submissions.count = 0

# name of the browse index to display collection's items.
# You can set a "item" type of browse index only.
#   default = title
#webui.collectionhome.browse-name = title

# how mamy items should be displayed per page in collection home page
#   default = 20
#webui.collectionhome.perpage = 20

# whether does use "dateaccessioned" as a sort option
#   If true and the sort option "dateaccessioned" exists, use "dateaccessioned" as a sort option.
#   Otherwise use the sort option pertaining the specified browse index.
#   default = true
#webui.collectionhome.use.dateaccessioned = true

# tell the community and collection pages that we are using the Recent
# Submissions code
#plugin.sequence.org.dspace.plugin.SiteHomeProcessor = \
#        org.dspace.app.webui.components.TopCommunitiesSiteProcessor,\
#        org.dspace.app.webui.components.RecentSiteSubmissions

#plugin.sequence.org.dspace.plugin.CommunityHomeProcessor = \
#        org.dspace.app.webui.components.RecentCommunitySubmissions

#plugin.sequence.org.dspace.plugin.CollectionHomeProcessor = \
#        org.dspace.app.webui.components.RecentCollectionSubmissions,\
#        org.dspace.app.webui.components.CollectionItemList

#### JSPUI Discovery (extra Discovery setting that applies only to JSPUI) ####
# uncomment the following configuration if you want to restore the legacy Lucene
# search provider with JSPUI (be sure to re-enable also the search consumer)
# plugin.single.org.dspace.app.webui.search.SearchRequestProcessor = \
#		org.dspace.app.webui.search.LuceneSearchRequestProcessor
#
# default since DSpace 4.0 is to use the Discovery search provider
plugin.single.org.dspace.app.webui.search.SearchRequestProcessor = \
		org.dspace.app.webui.discovery.DiscoverySearchRequestProcessor

#### XMLUI Discovery (extra Discovery setting that applies only to XMLUI) ####
# uncomment the following configuration if you want to restore the legacy Lucene
# search provider with XMLUI (be sure to re-enable also the search consumer)
# plugin.single.org.dspace.app.xmlui.aspect.administrative.mapper.SearchRequestProcessor = \
#		org.dspace.app.xmlui.aspect.administrative.mapper.LuceneSearchRequestProcessor
#
# default since DSpace 4.0 is to use the Discovery search provider
plugin.single.org.dspace.app.xmlui.aspect.administrative.mapper.SearchRequestProcessor = \
		org.dspace.app.xmlui.aspect.administrative.mapper.DiscoverySearchRequestProcessor

#### Sidebar Facets ####
# to show facets on the site home page, community, collection
# comment out the following lines if you disable Discovery or don't want
# to show facets on side bars
# TagCloudProcessor is responsible for displaying a tag-cloud facet on the
# site home page, community or collection home page
plugin.sequence.org.dspace.plugin.CommunityHomeProcessor = \
        org.dspace.app.webui.components.RecentCommunitySubmissions,\
        org.dspace.app.webui.discovery.SideBarFacetProcessor
#        org.dspace.app.webui.tagcloud.TagCloudProcessor

plugin.sequence.org.dspace.plugin.CollectionHomeProcessor = \
        org.dspace.app.webui.components.CollectionItemList,\
        org.dspace.app.webui.discovery.SideBarFacetProcessor
#        org.dspace.app.webui.tagcloud.TagCloudProcessor
#        org.dspace.app.webui.components.RecentCollectionSubmissions,\

plugin.sequence.org.dspace.plugin.SiteHomeProcessor = \
        org.dspace.app.webui.components.TopCommunitiesSiteProcessor,\
        org.dspace.app.webui.components.RecentSiteSubmissions,\
        org.dspace.app.webui.discovery.SideBarFacetProcessor
#        org.dspace.app.webui.tagcloud.TagCloudProcessor

#### JSON JSPUI Request Handler ####
# define any JSON handler here
#
# comment out this line if you disable Discovery
plugin.named.org.dspace.app.webui.json.JSONRequest = \
	org.dspace.app.webui.discovery.DiscoveryJSONRequest = discovery,\
	org.dspace.app.webui.json.SubmissionLookupJSONRequest = submissionLookup,\
	org.dspace.app.webui.json.UploadProgressJSON = uploadProgress,\
	org.dspace.app.webui.handle.HandleJSONResolver = hdlresolver,\
	org.dspace.app.webui.json.CreativeCommonsJSONRequest = creativecommons

### i18n -  Locales / Language ####
# Default Locale
# A Locale in the form country or country_language or country_language_variant
# if no default locale is defined the server default locale will be used.
default.locale = en

# All the Locales, that are supported by this instance of DSpace
# A comma-separated list of Locales. All types of Locales country, country_language, country_language_variant
# Note that the appropriate file are present, especially that all the Messages_x.properties are there
# may be used, e. g: webui.supported.locales = en, de

#### Submission License substitution variables ####
# it is possible include contextual information in the submission license using substitution variables
# the text substitution is driven by a plugin implementation
plugin.named.org.dspace.content.license.LicenseArgumentFormatter = \
	org.dspace.content.license.SimpleDSpaceObjectLicenseFormatter = collection, \
	org.dspace.content.license.SimpleDSpaceObjectLicenseFormatter = item, \
	org.dspace.content.license.SimpleDSpaceObjectLicenseFormatter = eperson

#### Syndication Feed (RSS) Settings ######

# enable syndication feeds - links display on community and collection home pages
# (This setting is not used by XMLUI, as you enable feeds in your theme)
webui.feed.enable = false
# number of DSpace items per feed (the most recent submissions)
webui.feed.items = 4
# maximum number of feeds in memory cache
# value of 0 will disable caching
webui.feed.cache.size = 100
# number of hours to keep cached feeds before checking currency
# value of 0 will force a check with each request
webui.feed.cache.age = 48
# which syndication formats to offer
# use one or more (comma-separated) values from list:
# rss_0.90, rss_0.91, rss_0.92, rss_0.93, rss_0.94, rss_1.0, rss_2.0
webui.feed.formats = rss_1.0,rss_2.0,atom_1.0
# URLs returned by the feed will point at the global handle server (e.g. http://hdl.handle.net/123456789/1)
# Set to true to use local server URLs (i.e. http://myserver.myorg/handle/123456789/1)
webui.feed.localresolve = false

# Customize each single-value field displayed in the
# feed information for each item.  Each of
# the below fields takes a *single* metadata field
#
# The form is <schema prefix>.<element>[.<qualifier>|.*]
webui.feed.item.title = dc.title
webui.feed.item.date = dc.date.issued

# Customise the metadata fields to show in the feed for each item's description.
# Elements will be displayed in the order that they are specified here.
#
# The form is <schema prefix>.<element>[.<qualifier>|.*][(date)], ...
#
# Similar to the item display UI, the name of the field for display
# in the feed will be drawn from the current UI dictionary,
# using the key:
# "metadata.<field>"
#
# e.g.   "metadata.dc.title"
#        "metadata.dc.contributor.author"
#        "metadata.dc.date.issued"
webui.feed.item.description = dc.title, dc.contributor.author, \
                                                          dc.contributor.editor, dc.description.abstract, \
                                                          dc.description
# name of field to use for authors (Atom only) - repeatable
webui.feed.item.author = dc.contributor.author

# Customize the extra namespaced DC elements added to the item (RSS) or entry
# (Atom) element.  These let you include individual metadata values in a
# structured format for easy extraction by the recipient, instead of (or in
# addition to) appending these values to the Description field.
## dc:creator value(s)
#webui.feed.item.dc.creator = dc.contributor.author
## dc:date value (may be contradicted by webui.feed.item.date)
#webui.feed.item.dc.date = dc.date.issued
## dc:description (e.g. for a distinct field that is ONLY the abstract)
#webui.feed.item.dc.description = dc.description.abstract

# Customize the image icon included with the site-wide feeds:
# Must be an absolute URL, e.g.
## webui.feed.logo.url = https://localhost/themes/mysite/images/mysite-logo.png

# iTunes Podcast Enhanced RSS Feed Properties
# Add all the communities / collections, separated by commas (no spaces) that should
# have the iTunes podcast metadata added to their RSS feed.
# Default: Disabled, No collections or communities have iTunes Podcast enhanced metadata in their feed.
# webui.feed.podcast.collections =123456789/2,123456789/3
# webui.feed.podcast.communities =123456789/1

# Which MIMETypes of Bitstreams would you like to have podcastable in your item?
# Separate multiple entries with commas.
#webui.feed.podcast.mimetypes=audio/x-mpeg

# For the iTunes Podcast Feed, if you would like to specify an external media file,
# not on your DSpace server to be enclosed within the entry for each item,
# specify which metadata field will hold the URI to the external media file.
# This is useful if you store the metadata in DSpace, and a separate streaming server to host the media.
# Default: dc.source.uri
#webui.feed.podcast.sourceuri = dc.source.uri

#### OpenSearch Settings ####
# NB: for result data formatting, OpenSearch uses Syndication Feed Settings
# so even if Syndication Feeds are not enabled, they must be configured
# enable open search
websvc.opensearch.enable = false
# context for html request URLs - change only for non-standard servlet mapping
websvc.opensearch.uicontext = simple-search
# context for RSS/Atom request URLs - change only for non-standard servlet mapping
websvc.opensearch.svccontext = open-search/
# present autodiscovery link in every page head
websvc.opensearch.autolink = true
# number of hours to retain results before recalculating
websvc.opensearch.validity = 48
# short name used in browsers for search service
# should be 16 or fewer characters
websvc.opensearch.shortname = {{ .Values.dspace.opensearch.shortname }}
# longer (up to 48 characters) name
websvc.opensearch.longname = {{ .Values.dspace.opensearch.longname }}
# brief service description
websvc.opensearch.description = {{ .Values.dspace.opensearch.description }}
# location of favicon for service, if any must be 16X16 pixels
websvc.opensearch.faviconurl = http://www.dspace.org/images/favicon.ico
# sample query - should return results
websvc.opensearch.samplequery = photosynthesis
# tags used to describe search service
websvc.opensearch.tags = IR DSpace
# result formats offered - use 1 or more comma-separated from: html,atom,rss
# NB: html is required for autodiscovery in browsers to function,
# and must be the first in the list if present
websvc.opensearch.formats = html,atom,rss


#### Content Inline Disposition Threshold ####
#
# Set the max size of a bitstream that can be served inline
# Use -1 to force all bitstream to be served inline
# The 'webui.*' setting is for the JSPUI, and
# the 'xmlui.*' setting is for the XMLUI
webui.content_disposition_threshold = 8388608
xmlui.content_disposition_threshold = 8388608


#### Multi-file HTML document/site settings #####
#
# When serving up composite HTML items, how deep can the request be for us to
# serve up a file with the same name?
#
# e.g. if we receive a request for "foo/bar/index.html"
# and we have a bitstream called just "index.html"
# we will serve up that bitstream for the request if webui.html.max-depth-guess
# is 2 or greater.  If webui.html.max-depth-guess is 1 or less, we would not
# serve that bitstream, as the depth of the file is greater.
#
# If webui.html.max-depth-guess is zero, the request filename and path must
# always exactly match the bitstream name.  Default value is 3.
#
# The 'webui.*' setting is for the JSPUI, and
# the 'xmlui.*' setting is for the XMLUI
#
# webui.html.max-depth-guess = 3
# xmlui.html.max-depth-guess = 3


#### Sitemap settings #####
# the directory where the generated sitemaps are stored
sitemap.dir = ${dspace.dir}/persistent/sitemaps

#
# Comma-separated list of search engine URLs to 'ping' when a new Sitemap has
# been created.  Include everything except the Sitemap URL itself (which will
# be URL-encoded and appended to form the actual URL 'pinged').
#
sitemap.engineurls = http://www.google.com/webmasters/sitemaps/ping?sitemap=

# Add this to the above parameter if you have an application ID with Yahoo
# (Replace REPLACE_ME with your application ID)
# http://search.yahooapis.com/SiteExplorerService/V1/updateNotification?appid=REPLACE_ME&url=
#
# No known Sitemap 'ping' URL for MSN/Live search

#####  SHERPA/Romeo Integration Settings ####
# the SHERPA/RoMEO endpoint
sherpa.romeo.url = http://www.sherpa.ac.uk/romeo/api29.php

# to disable the sherpa/romeo integration
# uncomment the follow line
# webui.submission.sherparomeo-policy-enabled = false

# please register for a free api access key to get many benefits
# http://www.sherpa.ac.uk/news/romeoapikeys.htm
# sherpa.romeo.apikey = YOUR-API-KEY

#####  Authority Control Settings  #####
#plugin.named.org.dspace.content.authority.ChoiceAuthority = \
# org.dspace.content.authority.SampleAuthority = Sample, \
# org.dspace.content.authority.LCNameAuthority = LCNameAuthority, \
# org.dspace.content.authority.SHERPARoMEOPublisher = SRPublisher, \
# org.dspace.content.authority.SHERPARoMEOJournalTitle = SRJournalTitle, \
#  org.dspace.content.authority.SolrAuthority = SolrAuthorAuthority

#Uncomment to enable ORCID authority control
#plugin.named.org.dspace.content.authority.ChoiceAuthority = \
#    org.dspace.content.authority.SolrAuthority = SolrAuthorAuthority

## The DCInputAuthority plugin is automatically configured with every
## value-pairs element in input-forms.xml, namely:
##   common_identifiers, common_types, common_iso_languages
##
## The DSpaceControlledVocabulary plugin is automatically configured
## with every *.xml file in [dspace]/config/controlled-vocabularies,
## and creates a plugin instance for each, using base filename as the name.
## eg: nsi, srsc.
## Each DSpaceControlledVocabulary plugin comes with three configuration options:
# vocabulary.plugin._plugin_.hierarchy.store = <true|false>    # default: true
# vocabulary.plugin._plugin_.hierarchy.suggest = <true|false>  # default: true
# vocabulary.plugin._plugin_.delimiter = "<string>"            # default: "::"
##
## An example using "srsc" can be found later in this section

#plugin.selfnamed.org.dspace.content.authority.ChoiceAuthority = \
# org.dspace.content.authority.DCInputAuthority, \
# org.dspace.content.authority.DSpaceControlledVocabulary

## configure LC Names plugin
#lcname.url = http://alcme.oclc.org/srw/search/lcnaf

##
## This sets the default lowest confidence level at which a metadata value is included
## in an authority-controlled browse (and search) index.  It is a symbolic
## keyword, one of the following values (listed in descending order):
##   accepted
##   uncertain
##   ambiguous
##   notfound
##   failed
##   rejected
##   novalue
##   unset
## See manual or org.dspace.content.authority.Choices source for descriptions.
authority.minconfidence = ambiguous

# Configuration settings for ORCID based authority control, uncomment the lines below to enable configuration
#solr.authority.server=http://localhost:8080/solr/authority
#choices.plugin.dc.contributor.author = SolrAuthorAuthority
#choices.presentation.dc.contributor.author = authorLookup
#authority.controlled.dc.contributor.author = true
#
#authority.author.indexer.field.1=dc.contributor.author

## demo: use LC plugin for author
#choices.plugin.dc.contributor.author =  LCNameAuthority
#choices.presentation.dc.contributor.author = lookup
#authority.controlled.dc.contributor.author = true
##
## This sets the lowest confidence level at which a metadata value is included
## in an authority-controlled browse (and search) index.  It is a symbolic
## keyword from the same set as for the default "authority.minconfidence"
#authority.minconfidence.dc.contributor.author = accepted

## demo: subject code autocomplete, using srsc as authority
## (DSpaceControlledVocabulary plugin must be enabled)
## Warning: when enabling this feature any controlled vocabulary configuration in the input-forms.xml for the metadata field will be overridden.
#choices.plugin.dc.subject = srsc
#choices.presentation.dc.subject = select
#vocabulary.plugin.srsc.hierarchy.store = true
#vocabulary.plugin.srsc.hierarchy.suggest = true
#vocabulary.plugin.srsc.delimiter = "::"

## Demo: publisher name lookup through SHERPA/RoMEO:
#choices.plugin.dc.publisher = SRPublisher
#choices.presentation.dc.publisher = suggest

## demo: journal title lookup, with ISSN as authority
#choices.plugin.dc.title.alternative = SRJournalTitle
#choices.presentation.dc.title.alternative = suggest
#authority.controlled.dc.title.alternative = true

## demo: use choice authority (without authority-control) to restrict dc.type on EditItemMetadata page
#choices.plugin.dc.type = common_types
#choices.presentation.dc.type = select

## demo: same idea for dc.language.iso
#choices.plugin.dc.language.iso = common_iso_languages
#choices.presentation.dc.language.iso = select

# Change number of choices shown in the select in Choices lookup popup
#xmlui.lookup.select.size = 12


#### Ordering of bitstreams ####

## Specify the ordering that bitstreams are listed.
##
## Bitstream field to sort on.  Values: sequence_id or name. Default: sequence_id
webui.bitstream.order.field = bitstream_order

## Direction of sorting order. Values: DESC or ASC. Default: ASC
#webui.bitstream.order.direction = ASC


##### Google Scholar Metadata Configuration #####
google-metadata.config = ${dspace.dir}/config/crosswalks/google-metadata.properties
google-metadata.enable = true

#---------------------------------------------------------------#
#--------------JSPUI SPECIFIC CONFIGURATIONS--------------------#
#---------------------------------------------------------------#
# These configs are only used by the JSP User Interface         #
#---------------------------------------------------------------#
##### JSPUI Layout #####
# set this value if you want to use a diffent main template.
# The value must match the name of a subfolder of dspace-jspui/src/main/webapp/layout
# jspui.template.name =

##### Show community or collection logo in list #####
# jspui.home-page.logos = true
# jspui.community-home.logos = true
# jspui.community-list.logos = true

##### Item Home Processor #####

plugin.sequence.org.dspace.plugin.ItemHomeProcessor = \
        org.dspace.app.webui.components.VersioningItemHome

##### Upload File settings #####

# Where to temporarily store uploaded files
upload.temp.dir = ${dspace.dir}/upload

# Maximum size of uploaded files in bytes, negative setting will result in no limit being set
# 512Mb
upload.max = 536870912


###### Statistical Report Configuration Settings ######

# should the stats be publicly available?  should be set to false if you only
# want administrators to access the stats, or you do not intend to generate
# any
report.public = false

# directory where live reports are stored
report.dir = ${dspace.dir}/persistent/reports/



###### Web Interface Settings ######


# Customise the DC metadata fields to show in the default simple item view.
#
# The form is <schema prefix>.<element>[.<qualifier>|.*][(date)|(link)|(nobreakline)], ...
#
# For example:
#    dc.title               = Dublin Core element 'title' (unqualified)
#    dc.title.alternative   = DC element 'title', qualifier 'alternative'
#    dc.title.*             = All fields with Dublin Core element 'title'
#                             (any or no qualifier)
#    dc.identifier.uri(link) = DC identifier.uri, render as a link
#    dc.date.issued(date)   = DC date.issued, render as a date
#    dc.subject(nobreakline)   = DC subject.keyword, rendered as separated values
#                               (see also webui.itemdisplay.nobreakline.separator option)
#    dc.language(inputform)   = If the dc.language is in a controlled vocabulary, then the displayed value will be shown based on the stored value from the value-pairs-name in input forms.
#			      The input-forms will be loaded based on the session locale. If the displayed value is not found, then the value will be shown as is.
#    "link/date" options can be combined with "nobreakline" option using a space among them i.e "dc.identifier.uri(link nobreakline)"
#
# If an item has no value for a particular field, it won't be displayed.
# The name of the field for display will be drawn from the current UI
# dictionary, using the key:
#
# "metadata.<style>.<field>" or if undefined the key "metadata.<field>"
#
# e.g.   "metadata.default.dc.title" or "metadata.default.dc.title"
#        "metadata.dc.contributor.*" or "metadata.default.dc.contributor.*"
#        "metadata.dc.date.issued" or "metadata.default.dc.date.issued"
#
#webui.itemdisplay.default = dc.title, dc.title.alternative, dc.contributor.*, \
#                            dc.subject(nobreakline), dc.date.issued(date), dc.publisher, \
#                            dc.identifier.citation, dc.relation.ispartofseries, \
#                            dc.description.abstract, dc.description, \
#                            dc.identifier.govdoc, dc.identifier.uri(link), \
#                            dc.identifier.isbn, dc.identifier.issn, \
#                            dc.identifier.ismn, dc.identifier
#
# When using "resolver" in webui.itemdisplay to render identifiers as resolvable
# links, the base URL is taken from <code>webui.resolver.<n>.baseurl</code>
# where <code>webui.resolver.<n>.urn</code> matches the urn specified in the metadata value.
# The value is appended to the "baseurl" as is, so the baseurl need to end with slash almost in any case.
# If no urn is specified in the value it will be displayed as simple text.
#
#webui.resolver.1.urn = doi
#webui.resolver.1.baseurl = http://dx.doi.org/
#webui.resolver.2.urn = hdl
#webui.resolver.2.baseurl = http://hdl.handle.net/
#
# For the doi and hdl urn defaults values are provided, respectively http://dx.doi.org and
# http://hdl.handle.net are used.<br>
#
# If a metadata value with style: "doi", "handle" or "resolver" matches a URL
# already, it is simply rendered as a link with no other manipulation.

# If nobreakline option is applied for a field in itemdisplay then the following option defines the separator string.
# If a non-breaking space is needed before or after the separator, this can be included using &nbsp;
# (i.e. webui.itemdisplay.separator = ;&nbsp;)
# If ommitted, the default separator is ';&nbsp;'
webui.itemdisplay.nobreakline.separator = ;

# Specify which strategy use for select the style for an item
plugin.single.org.dspace.app.webui.util.StyleSelection = \
                       org.dspace.app.webui.util.CollectionStyleSelection
                       #org.dspace.app.webui.util.MetadataStyleSelection

# If use CollectionStyleSelection
# Specify which collections use which views by Handle.
#
# webui.itemdisplay.<style>.collections = <collection handle>, ...
#
# FIXME: This should be more database-driven
#
# webui.itemdisplay.thesis.collections = 123456789/24, 123456789/35

# If use MetadataStyleSelection, you MUST
# Specify which metadata use as name of the style
#
# webui.itemdisplay.metadata-style = schema.element[.qualifier|.*]
# webui.itemdisplay.metadata-style = dc.type

# Customise the DC fields to use in the item listing page.  Elements will be
# displayed left to right in the order that they are specified here.
#
# The form is <schema prefix>.<element>[.<qualifier>|.*][(date)], ...
#
# Although not a requirement, it would make sense to include among the listed
# fields at least the date and title fields as specified by the
# webui.browse.index.* configuration options below.
#
# If you have enabled thumbnails (webui.browse.thumbnail.show), you must also
# include a 'thumbnail' entry in your columns - this is where the thumbnail will be displayed
#
# If you want to mark each item include a 'mark_[value]' (without the brackets - replace the word 'value' with anything that
# has a meaning for your mark) entry in your columns - this is where the icon will be displayed.
# Do not forget to add a Spring bean with id = "org.dspace.app.itemmarking.ItemMarkingExtractor.[value]"
# in file 'config/spring/api/item-marking.xml'. This bean is responsible for drawing the appropriate mark for each item.
# You can add more than one 'mark_[value]' options (with different value) in case you need to mark items more than one time for
# different purposes. Remember to add the respective beans in file 'config/spring/api/item-marking.xml'.
#
# webui.itemlist.columns = thumbnail, dc.date.issued(date), dc.title, dc.contributor.*
#
# You can customise the width of each column with the following line - you can have numbers (pixels)
# or percentages. For the 'thumbnail' column, a setting of '*' will use the max width specified
# for browse thumbnails (webui.browse.thumbnail.maxwidth, thumbnail.maxwidth)
# webui.itemlist.widths = *, 130, 60%, 40%

# Additionally, you can override the DC fields used on the listing page for
# a given browse index and/or sort option. As a sort option or index may be defined
# on a field that isn't normally included in the list, this allows you to display
# the fields that have been indexed / sorted on.
#
# There are a number of forms the configuration can take, and the order in which
# they are listed below is the priority in which they will be used (so a combination
# of an index name and sort name will take precedence over just the browse name).
#
# webui.itemlist.browse.<index name>.sort.<sort name>.columns
# webui.itemlist.sort.<sort name>.columns
# webui.itemlist.browse.<browse name>.columns
# webui.itemlist.<sort or index name>.columns
#
# In the last case, a sort option name will always take precedence over a browse
# index name. Note also, that for any additional columns you list, you will need to
# ensure there is an itemlist.<field name> entry in the messages file.
#
# The following example would display the date of accession in place of the issue date
# whenever the dateaccessioned browse index or sort option is selected.
#
# Just like webui.itemlist.columns, you will need to include a 'thumbnail' entry to display
# and thumbnails in the item list
#
# webui.itemlist.dateaccessioned.columns = thumbnail, dc.date.accessioned(date), dc.title, dc.contributor.*
#
# As above, you can customise the width of the columns for each configured column list, substituting '.widths' for
# '.columns' in the property name. See the setting for webui.itemlist.widths for more details
# webui.itemlist.dateaccessioned.widths = *, 130, 60%, 40%

# You can also set the overall size of the item list table with the following setting. It can lead to faster
# table rendering when used with the column widths above, but not generally recommended.
# webui.itemlist.tablewidth = 100%


#### Additional configuration for Item Mapper ####

# the index name (from webui.browse.index above) to use for
# displaying items by author
#
itemmap.author.index = author


### MyDSpace display of group membership ####
#
# if omitted, the default behaviour is false
#
# webui.mydspace.showgroupmemberships = false


### Configure the search indices to appear in advanced search drop down lists
#
jspui.search.index.display.1 = ANY
jspui.search.index.display.2 = author
jspui.search.index.display.3 = title
jspui.search.index.display.4 = keyword
jspui.search.index.display.5 = abstract
jspui.search.index.display.6 = series
jspui.search.index.display.7 = sponsor
jspui.search.index.display.8 = identifier
jspui.search.index.display.9 = language


##### SFX Server (OpenURL) #####

# SFX query is appended to this URL.  If this property is commented out or
# omitted, SFX support is switched off.
# sfx.server.url = http://sfx.myu.edu:8888/sfx?

# This image will be displayed in the SFX link. If commented out, the SFX link will be only a text link.
# This customization usually contains an institution-branded SFX button.
# sfx.server.image_url = http://sfx.my.edu:8888/sfx.gif


#### Item Recommendation Settings #####

# show a link to the item recommendation page from item display page
webui.suggest.enable = false
#
# Enable only, if the user is logged in.
# If not set the  default value is  false
# webui.suggest.loggedinusers.only = true


#### Controlled Vocabulary Settings #####

# Enable or disable the controlled vocabulary add-on
# Warning: this feature is not compatible with WAI (it requires javascript to function)
#
# webui.controlledvocabulary.enable = true


#### Session invalidation #####

# Enable or disable session invalidation upon login or logout.
# This feature is enabled by default to help prevent session hijacking
# but may cause problems for shibboleth, etc
#
# webui.session.invalidate = true

# If you would like to use Google Analytics to track general website statistics then
# use the following parameter to provide your Analytics key. First sign up for an
# account at http://analytics.google.com, then create an entry for your repository
# website. Analytics will give you a snipet of JavaScript code to place on your site,
# inside that snipet is your Google Analytics key usually found in this line:
# _uacct = "UA-XXXXXXX-X"
# Take this key (just the UA-XXXXXX-X part) and place it here in this parameter.
{{- if .Values.dspace.googleAnalyticsKey }}
jspui.google.analytics.key={{ .Values.dspace.googleAnalyticsKey }}
{{ end }}
#---------------------------------------------------------------#
#--------------XMLUI SPECIFIC CONFIGURATIONS--------------------#
#---------------------------------------------------------------#
# These configs are only used by the XML User Interface         #
#---------------------------------------------------------------#


# Force all authenticated connections to use SSL, only non-authenticated
# connections are allowed over plain http. If set to true, then you need to
# ensure that the 'dspace.hostname' parameter is set to the correctly.
#xmlui.force.ssl = true

# Determine if new users should be allowed to register or edit their own metadata.
# These parameters are useful in conjunction with shibboleth where you want to
# disallow registration and disable the user's ability to edit their metadata
# because both come from Shibboleth.
#xmlui.user.registration=true
#xmlui.user.editmetadata=true

# Check if the user has a consistent ip address from the start of the login process
# to the end of the login process. Disabling this check is not recommended unless
# absolutely necessary as the ip check can be helpful for preventing session
# hijacking. Possible reasons to set this to false: many-to-many wireless networks
# that prevent consistent ip addresses or complex proxying of requests.
# The default value is set to true.
#xmlui.session.ipcheck = true

# After a user has logged into the system, which url should they be directed too?
# Leave this parameter blank or undefined to direct users to the homepage, or
# "/profile" for the user's profile, or another reasonable choice is "/submissions"
# to see if the user has any tasks awaiting their attention. The default is the
# repository home page.
#xmlui.user.loginredirect=/profile

# Allow the user to override which theme is used to display a particular page.
# When submitting a request add the HTTP parameter "themepath" which corresponds
# to a particular theme, that specified theme will be used instead of the any
# other configured theme. Note that this is a potential security hole allowing
# execution of unintended code on the server, this option is only for development
# and debugging it should be turned off for any production repository. The default
# value unless otherwise specified is "false"
#xmlui.theme.allowoverrides = false

# Enabling this property will concatenate CSS, JS and JSON files where possible.
# CSS files can be concatenated if multiple CSS files with the same media attribute
# are used in the same page. Links to the CSS files are automatically referring to the
# concatenated resulting CSS file.
# The theme sitemap should be updated to use the ConcatenationReader for all js, css and json
# files before enabling this property.
#xmlui.theme.enableConcatenation = false

# Enabling this property will minify CSS, JS and JSON files where possible.
# The theme sitemap should be updated to use the ConcatenationReader for all js, css and json
# files before enabling this property.
#xmlui.theme.enableMinification = false

# Themes only allow specific file formats (extensions) to be accessible, for security reasons.
# While the default list should work for most sites, you may wish to customize it.  The default
# list is commented out below. To customize, just uncomment and add more file extensions.
#xmlui.theme.whitelist = css, js, json, gif, jpg, jpeg, png, bmp, ico, htm, html, svg, ttf, woff

### Settings for Item lists in Mirage theme ###
# What should the emphasis be in the display of item lists?
# Possible values : 'file', 'metadata'. If your repository is
# used mainly for scientific papers 'metadata' is probably the
# best way. If you have a lot of images and other files 'file'
# will be the best starting point
# (metdata is the default value if this option is not specified)
#xmlui.theme.mirage.item-list.emphasis = file

### Settings for the Item page in Mirage2 theme ###
# Whether the title or the label of a file should be used to display it on the item page
mirage2.item-view.bitstream.href.label.1 = label
# Whether the title or the label of a file should be used as a fallback to display it on the item page
mirage2.item-view.bitstream.href.label.2 = title

# Determine which bundles administrators and collection administrators may upload
# into an existing item through the administrative interface. If the user does not
# have the appropriate privileges (add & write) on the bundle then that bundle will
# not be shown to the user as an option.
#xmlui.bundle.upload = ORIGINAL, METADATA, THUMBNAIL, LICENSE, CC-LICENSE

# On the community-list page should all the metadata about a community/collection
# be available to the theme. This parameter defaults to true, but if you are
# experiencing performance problems on the community-list page you should experiment
# with turning this option off.
#xmlui.community-list.render.full = false

# Normally, Manakin will fully verify any cache pages before using a cache copy.
# This means that when the community-list page is viewed the database is queried
# for each community/collection to see if their metadata has been modified. This
# can be expensive for repositories with a large community tree. To help solve
# this problem you can set the cache to be assumed valued for a specific set of time.
# The downside of this is that new or editing communities/collections may not show up
# the website for a period of time.
#xmlui.community-list.cache = 12 hours

# Optionally you may configure Manakin to take advantage of metadata stored as a
# bitstream. These metadata files should be inside the "METADATA" bundle and named
# either MODS.xml or METS.xml. If either of the following options are turned on then
# these files will be made available to the theme when rendering an item.
#xmlui.bitstream.mods = true
#xmlui.bitstream.mets = true

# If you would like to use Google Analytics to track general website statistics then
# use the following parameter to provide your Analytics key. First sign up for an
# account at http://analytics.google.com, then create an entry for your repository
# website. Analytics will give you a snipet of JavaScript code to place on your site,
# inside that snipet is your Google Analytics key usually found in this line:
# _uacct = "UA-XXXXXXX-X"
# Take this key (just the UA-XXXXXX-X part) and place it here in this parameter.
#xmlui.google.analytics.key=UA-XXXXXX-X

# Assign how many page views will be recorded and displayed in the control panel's
# activity viewer. The activity tab allows an administrator to debug problems in a
# running DSpace by understanding who and how their dspace is currently being used.
# The default value is 250.
#xmlui.controlpanel.activity.max = 250

# Determine where the control panel's activity viewer receives an event's IP address
# from. If your DSpace is in a load balanced enviornment or otherwise behind a
# context-switch then you will need to set the paramater to the HTTP parameter that
# records the original IP address.
#xmlui.controlpanel.activity.ipheader = X-Forwarded-For

#---------------------------------------------------------------#
#----------------REQUEST ITEM CONFIGURATION---------------------#
#---------------------------------------------------------------#

# Configuration of request-item. Possible values:
# all - Anonymous users can request an item
# logged - Login is mandatory to request an item
# empty/commented out - request-copy not allowed
request.item.type = all
# Helpdesk E-mail
mail.helpdesk = pan.luo@ubc.ca
# Should all Request Copy emails go to the helpdesk instead of the item submitter?
request.item.helpdesk.override = false

#------------END REQUEST ITEM CONFIGURATION---------------------#

## StatSpace configuration

# Handle to the showcase collection (don't show if undefined)
statspace.showcase.handle =
{{- end -}}
