deploylocal : fhem_kill
	sudo cp FHEM/*.pm /opt/fhem/FHEM/
	sudo timeout 3 killall -qws2 perl || sudo killall -qws9 perl || true
	sudo rm /opt/fhem/log/fhem-*.log || true
	sudo cp test/fhem.cfg /opt/fhem/fhem.cfg
	sudo rm /opt/fhem/log/fhem.save || true
	TZ=Europe/Berlin 

test_%: fhem_start
	@d=$$(mktemp) && \
	test/test-runner.sh ${@F} >> $$d 2>&1 && \
	flock /tmp/my-lock-file cat $$d && \
    rm $$d
test_commandref:
	@echo === running commandref test ===
	git --no-pager diff --name-only ${TRAVIS_COMMIT_RANGE} | egrep "\.pm" | xargs -I@ echo -select @ | xargs --no-run-if-empty perl /opt/fhem/contrib/commandref_join.pl 

SOURCES := $(shell find ./test -maxdepth 1 -name 'test_*-definition.txt')
SOURCES := $(subst -definition.txt,,$(SOURCES))

init: 
	@echo $(SOURCES)

test_all: deploylocal fhem_start | test_commandref ${SOURCES}
	@echo === TEST_ALL done ===

fhem_start: deploylocal
	cd /opt/fhem && perl -MDevel::Cover fhem.pl fhem.cfg && cd ${TRAVIS_BUILD_DIR}
	@echo === ready for unit tests ===

fhem_kill:
	@echo === finished unit tests ===
	sudo timeout 30 killall -vw perl || sudo killall -vws9 perl

test:  | fhem_start test_all 
	@echo === running unit tests ===
	$(MAKE) 

