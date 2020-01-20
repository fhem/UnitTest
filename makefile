.PHONY: fhem_start fhem_kill test test_all setupEnv info deploylocal clean test_commandref
space:=
space+=

PERL_OPTS?=

	
MAKEFILE_DIR:=$(subst $(space),\$(space),$(shell dirname $(subst $(space),\$(space),$(realpath $(lastword $(MAKEFILE_LIST))))))
CURDIR_ESCAPED := $(subst $(space),\$(space),$(CURDIR))
SOURCES := $(shell test -d ${MAKEFILE_DIR}/tests && find ${MAKEFILE_DIR}/tests -maxdepth 1 -name 'test_*-definition.txt')
SOURCES := $(subst -definition.txt,,$(filter test%-definition.txt,$(notdir $(SOURCES))))
TEST_RUNNER := ${MAKEFILE_DIR}/src/test-runner.sh
REPO_NAME := $(shell basename -s .git `git config --get remote.origin.url`)

# download shell scripts for running unittest
ifneq ($(REPO_NAME),UnitTest)
setupEnv:  src/fhemcl.sh src/test-runner.sh
	@echo "=== Downloading 98_unittest.pm ->  /opt/fhem/FHEM ==="
	@[ -d /opt/fhem/FHEM/ ] && wget -O /opt/fhem/FHEM/98_unittest.pm https://raw.githubusercontent.com/fhem/UnitTest/master/FHEM/98_unittest.pm
src/%.sh:
	@echo "=== Downloading $@ ==="
	@mkdir -p $(MAKEFILE_DIR)/src
	@wget -O $(MAKEFILE_DIR)/$@ https://raw.githubusercontent.com/fhem/UnitTest/master/$@
	chmod +x $(MAKEFILE_DIR)/$@
clean:
	@rm ${MAKEFILE_DIR}/src/fhemcl.sh && rm ${MAKEFILE_DIR}/src/test-runner.sh || true
endif

deploylocal : fhem_kill
	@echo "=== Deploy and start FHEM ==="
	@sudo cp $(CURDIR_ESCAPED)/FHEM/*.pm /opt/fhem/FHEM/
	@[ -f $(MAKEFILE_DIR)/fhem_ut.cfg ] && sudo cp $(MAKEFILE_DIR)/fhem_ut.cfg /opt/fhem/fhem_ut.cfg || true
	@sudo rm -f /opt/fhem/log/fhem.save || true
	@TZ=Europe/Berlin 

test_%: fhem_start
	@if [ ! "$(findstring $@, $(SOURCES))" = "$@" ]; then \
		echo "No file named $@"; \
	else \
		sudo rm -f /opt/fhem/log/fhem-*-$@.log 2&1>/dev/null || true; \
		d=$$(mktemp) && ${TEST_RUNNER} ${@F} >> $$d 2>&1; \
		RC=$$?; \
		flock /tmp/my-lock-file cat $$d ; \
		rm $$d; \
		(exit $$RC); \
	fi

test_commandref:
	@echo "=== running commandref test ==="
	$(eval CREF_RESULT="$(shell cd ${CURDIR_ESCAPED} && git --no-pager diff --diff-filter=d --name-only ${TRAVIS_COMMIT_RANGE} | egrep "\.pm" | xargs -I@ echo -select @ | xargs --no-run-if-empty perl /opt/fhem/contrib/commandref_join.pl )")
	@if [ "$(findstring negative, $(CREF_RESULT))" = "negative" ]; then \
		echo "error"; \
		echo ${CREF_RESULT}; \
		(exit 10); \
	else \
		echo "commandref is ok"; \
	fi

#	if [ "$$CREF_RESULT" =~  ]; then \
#	fi;

init: 
	@echo "      SOURCES: $(SOURCES)"
	@echo "       CURDIR: ${CURDIR_ESCAPED}"
	@echo "MAKEFILE_LIST: $(MAKEFILE_LIST)"
	@echo " MAKEFILE_DIR: $(MAKEFILE_DIR)"
	@echo "    REPO_NAME: $(REPO_NAME)"
	

test_all: test_commandref deploylocal fhem_start test_modules |  ${SOURCES}
	@echo === TEST_ALL done ===

fhem_start: deploylocal
	@echo === Starting FHEM ===
	cd /opt/fhem && perl ${PERL_OPTS} fhem.pl fhem_ut.cfg && cd ${CURDIR_ESCAPED}

fhem_kill:
	@echo === kill FHEM processes ===
	@sudo pkill -f -x "perl.*fhem.pl.*" || true

test:  | fhem_start test_all 
	@echo === Running unit tests ===
	# $(MAKE)


