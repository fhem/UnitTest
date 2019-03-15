.PHONY: fhem_start fhem_kill
MAKEFILE_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SOURCES := $(shell find ${MAKEFILE_DIR}/tests -maxdepth 1 -name 'test_*-definition.txt')
SOURCES := $(subst -definition.txt,,$(SOURCES))



deploylocal : fhem_kill
	@sudo cp ${MAKEFILE_DIR}/FHEM/*.pm /opt/fhem/FHEM/
	@sudo cp ${MAKEFILE_DIR}/fhem_ut.cfg /opt/fhem/fhem_ut.cfg
	@sudo rm /opt/fhem/log/fhem.save || true
	@TZ=Europe/Berlin 

test_%: fhem_start
	@sudo rm /opt/fhem/log/fhem-*-$1.log || true
	@d=$$(mktemp) && \
	${MAKEFILE_DIR}/src/test-runner.sh ${@F} >> $$d 2>&1 && \
	flock /tmp/my-lock-file cat $$d && \
    rm $$d
test_commandref:
	@echo === running commandref test ===
	cd ${MAKEFILE_DIR} && git --no-pager diff --name-only ${TRAVIS_COMMIT_RANGE} | egrep "\.pm" | xargs -I@ echo -select @ | xargs --no-run-if-empty perl /opt/fhem/contrib/commandref_join.pl 



init: 
	@echo $(SOURCES)
	@echo ${MAKEFILE_DIR}

test_all: test_commandref deploylocal fhem_start |  ${SOURCES}
	@echo === TEST_ALL done ===

fhem_start: deploylocal
	cd /opt/fhem && perl fhem.pl fhem_ut.cfg && cd ${MAKEFILE_DIR}
	@echo === ready for unit tests ===
fhem_kill:
	@echo === finished unit tests ===
	@sudo pkill -f -x "perl fhem.pl fhem*.cfg" || true

test:  | fhem_start test_all 
	@echo === running unit tests ===
	$(MAKE) 

