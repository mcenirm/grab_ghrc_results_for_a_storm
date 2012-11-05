

SCRIPTS_DIR = scripts
OUTPUT_DIR = output
CACHE_DIR = cache

CONFIG = $(OUTPUT_DIR)/this.config

FETCH = $(SCRIPTS_DIR)/fetch

OUTPUT_EVENTS_DIR = $(OUTPUT_DIR)/events
OUTPUT_METADATA_DIR = $(OUTPUT_DIR)/metadata

HURDAT_SOURCE = http://www.aoml.noaa.gov/hrd/hurdat/newhurdat-all.html
HURDAT_ALL_FILE = $(CACHE_DIR)/newhurdat-all.html
HURDAT_FILE = $(OUTPUT_DIR)/newhurdat-2000-2011.txt

OUTPUT_STORMS_DIR = $(OUTPUT_EVENTS_DIR)/storms
HURDAT2_s := $(wildcard $(OUTPUT_STORMS_DIR)/AL??????.hurdat2)

CACHE_ECHO_DIR = $(CACHE_DIR)/echo-results
OUTPUT_ECHO_DIR = $(OUTPUT_METADATA_DIR)/echo-results
ECHO_BIGLIST = $(OUTPUT_ECHO_DIR)/biglist
ECHO_GRANULES_BY_STORM_s := $(patsubst $(OUTPUT_STORMS_DIR)/%.hurdat2,$(CACHE_ECHO_DIR)/%.echo-granules,$(HURDAT2_s))

GHRC_GHOST=http://ghrc.nsstc.nasa.gov/hydro/ghost.pl
CACHE_GHRC_DIR = $(CACHE_DIR)/ghrc-results
CACHE_GHRC_BY_STORM_DIR = $(CACHE_GHRC_DIR)/by-storm
OUTPUT_GHRC_DIR = $(OUTPUT_DIR)/ghrc-results
OUTPUT_GHRC_BY_STORM_DIR = $(OUTPUT_GHRC_DIR)/by-storm
GHRC_GRANULES_BY_STORM_s := $(patsubst $(OUTPUT_STORMS_DIR)/%.hurdat2,$(OUTPUT_GHRC_BY_STORM_DIR)/%.ghrc-granules.csv,$(HURDAT2_s))

XMLNS_ATOM = http://www.w3.org/2005/Atom
XMLNS_OS = http://a9.com/-/spec/opensearch/1.1/
XMLNS_HYDRO = http://ghrc.nsstc.nasa.gov/hydro/
XMLNS_TIME = http://a9.com/-/opensearch/extensions/time/1.0/
XMLNS_GEO = http://a9.com/-/opensearch/extensions/geo/1.0/


############################################################


#all : $(ECHO_BIGLIST)
#all : $(OUTPUT_GHRC_BY_STORM_DIR)/AL012011.ghrc-dslist
#all : $(OUTPUT_GHRC_BY_STORM_DIR)/AL012011.ghrc-granules.csv
all : $(GHRC_GRANULES_BY_STORM_s)


config : $(CONFIG)

$(CONFIG) : $(lastword $(MAKEFILE_LIST))
	@mkdir -p $(@D)
	echo > $@
	echo "CONFIG=\"$(CONFIG)\"" >> $@
	echo "SCRIPTS_DIR=\"$(SCRIPTS_DIR)\"" >> $(CONFIG)
	echo "OUTPUT_DIR=\"$(OUTPUT_DIR)\"" >> $(CONFIG)
	echo "CACHE_DIR=\"$(CACHE_DIR)\"" >> $(CONFIG)
	echo "CONFIG=\"$(CONFIG)\"" >> $(CONFIG)
	echo "FETCH=\"$(FETCH)\"" >> $(CONFIG)
	echo "OUTPUT_EVENTS_DIR=\"$(OUTPUT_EVENTS_DIR)\"" >> $(CONFIG)
	echo "OUTPUT_METADATA_DIR=\"$(OUTPUT_METADATA_DIR)\"" >> $(CONFIG)
	echo "HURDAT_SOURCE=\"$(HURDAT_SOURCE)\"" >> $(CONFIG)
	echo "HURDAT_ALL_FILE=\"$(HURDAT_ALL_FILE)\"" >> $(CONFIG)
	echo "HURDAT_FILE=\"$(HURDAT_FILE)\"" >> $(CONFIG)
	echo "OUTPUT_STORMS_DIR=\"$(OUTPUT_STORMS_DIR)\"" >> $(CONFIG)
	echo "HURDAT2_s=\"$(HURDAT2_s)\"" >> $(CONFIG)
	echo "CACHE_ECHO_DIR=\"$(CACHE_ECHO_DIR)\"" >> $(CONFIG)
	echo "OUTPUT_ECHO_DIR=\"$(OUTPUT_ECHO_DIR)\"" >> $(CONFIG)
	echo "ECHO_BIGLIST=\"$(ECHO_BIGLIST)\"" >> $(CONFIG)
	echo "ECHO_GRANULES_BY_STORM_s=\"$(ECHO_GRANULES_BY_STORM_s)\"" >> $(CONFIG)
	echo "GHRC_GHOST=\"$(GHRC_GHOST)\"" >> $(CONFIG)
	echo "CACHE_GHRC_DIR=\"$(CACHE_GHRC_DIR)\"" >> $(CONFIG)
	echo "CACHE_GHRC_BY_STORM_DIR=\"$(CACHE_GHRC_BY_STORM_DIR)\"" >> $(CONFIG)
	echo "OUTPUT_GHRC_DIR=\"$(OUTPUT_GHRC_DIR)\"" >> $(CONFIG)
	echo "OUTPUT_GHRC_BY_STORM_DIR=\"$(OUTPUT_GHRC_BY_STORM_DIR)\"" >> $(CONFIG)
	echo "XMLNS_ATOM=\"$(XMLNS_ATOM)\"" >> $(CONFIG)
	echo "XMLNS_OS=\"$(XMLNS_OS)\"" >> $(CONFIG)
	echo "XMLNS_HYDRO=\"$(XMLNS_HYDRO)\"" >> $(CONFIG)
	echo "XMLNS_TIME=\"$(XMLNS_TIME)\"" >> $(CONFIG)
	echo "XMLNS_GEO=\"$(XMLNS_GEO)\"" >> $(CONFIG)
	echo >> $@


############################################################


# list of granules (all datasets) for a storm
$(OUTPUT_GHRC_BY_STORM_DIR)/%.ghrc-granules.csv : $(CONFIG) $(OUTPUT_STORMS_DIR)/%.xml
	@mkdir -p $(@D)
	$(SCRIPTS_DIR)/grab_ghrc_results_for_a_storm $+ > $@


# list of datasets (shortname osddurl title) for a storm
$(OUTPUT_GHRC_BY_STORM_DIR)/%.ghrc-dslist : $(CACHE_GHRC_BY_STORM_DIR)/%.ghrc-datasets
	@mkdir -p $(@D)
	xmlstarlet sel -N atom=$(XMLNS_ATOM) \
	    -T -t -m /atom:feed/atom:entry \
	    -v 'atom:link[@rel="search"]/@href' -o ' ' -v atom:title -n $< \
	    | sed -e 's,^.*\&ds=\([^&]*\)\&.*$$,\1 &,' \
	    > $@


# GHRC opensearch dataset results for a storm
$(CACHE_GHRC_BY_STORM_DIR)/%.ghrc-datasets : $(OUTPUT_GHRC_BY_STORM_DIR)/%.ghrc-request-parameters
	@mkdir -p $(@D)
	$(FETCH) $(GHRC_GHOST)\?q=ds\&format=atom$$(cat $<) $@


# GHRC opensearch request parameters for a storm
$(OUTPUT_GHRC_BY_STORM_DIR)/%.ghrc-request-parameters : $(OUTPUT_STORMS_DIR)/%.xml
	@mkdir -p $(@D)
	xmlstarlet sel -T -t -m //storm -o \&aoi= -v bbox -o \&from= -v from -o \&thru= -v thru -n $< > $@


############################################################


# list of all granule references
$(ECHO_BIGLIST) : $(ECHO_GRANULES_BY_STORM_s)
	@mkdir -p $(@D)
	xmlstarlet sel -T -t -m //reference -v location -n $^ | sort -u > $@


# ECHO granule list for a storm
$(CACHE_ECHO_DIR)/%.echo-granules : $(OUTPUT_STORMS_DIR)/%.xml
	@mkdir -p $(@D)
	$(FETCH) https://api.echo.nasa.gov/catalog-rest/echo_catalog/granules\?page_size=2000\&page_num=1\&sort_key%5B%5D=-start_date$$(xmlstarlet sel -T -t -m //storm -o \&bounding_box= -v bbox -o \&temporal%5B%5D= -v from -o , -v thru -n $<) $@


############################################################


# each storm as a simplistic XML file
$(OUTPUT_STORMS_DIR)/%.xml : $(OUTPUT_STORMS_DIR)/%.hurdat2
	$(SCRIPTS_DIR)/hurdat2_to_xml $< > $@


hurdat: $(OUTPUT_STORMS_DIR)/x.hurdat2

# each storm as a HURDAT2 file
$(OUTPUT_STORMS_DIR)/%.hurdat2 : $(HURDAT_FILE)
	@mkdir -p $(@D)
	$(SCRIPTS_DIR)/hurdat2_splitter $(OUTPUT_STORMS_DIR) $<


# HURDAT2 file containing only years 2000-2099
$(HURDAT_FILE) : $(HURDAT_ALL_FILE)
	@mkdir -p $(@D)
	cat $< | dos2unix | sed -n -e '/^....20.., ..............., ......,$$/p' -e '/^20......, ....,/p' > $@


# HURDAT2 data file for North Atlantic
# cf http://www.aoml.noaa.gov/hrd/data_sub/re_anal.html
$(HURDAT_ALL_FILE) :
	@mkdir -p $(@D)
	$(FETCH) $(HURDAT_SOURCE) $@


############################################################


.SECONDARY :

.PHONY : clean realclean

clean :
	-rm -r $(OUTPUT_DIR)

realclean : clean
	-rm -r $(CACHE_DIR)

