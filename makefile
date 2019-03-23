.PHONY: fhem_start fhem_kill test test_all
space:=
space+=

MAKEFILE_DIR:=$(subst $(space),\$(space),$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST)))))
CURDIR_ESCAPED := $(subst $(space),\$(space),$(CURDIR))
SOURCES := $(shell test -d ${CURDIR_ESCAPED}/tests && find ${CURDIR_ESCAPED}/tests -maxdepth 1 -name 'test_*-definition.txt')
SOURCES := $(subst -definition.txt,,$(SOURCES))





deploylocal : fhem_kill
	@sudo cp $(CURDIR_ESCAPED)/FHEM/*.pm /opt/fhem/FHEM/
	@[ -f $(CURDIR_ESCAPED)/fhem_ut.cfg ] && sudo cp $(CURDIR_ESCAPED)/fhem_ut.cfg /opt/fhem/fhem_ut.cfg || true
	@sudo rm /opt/fhem/log/fhem.save || true
	@TZ=Europe/Berlin 

test_%: fhem_start
	@sudo rm /opt/fhem/log/fhem-*-$1.log || true
	@d=$$(mktemp) && \
	${CURDIR_ESCAPED}/src/test-runner.sh ${@F} >> $$d 2>&1 && \
	flock /tmp/my-lock-file cat $$d && \
    rm $$d
test_commandref:
	@echo === running commandref test ===
	cd ${CURDIR_ESCAPED} && git --no-pager diff --name-only ${TRAVIS_COMMIT_RANGE} | egrep "\.pm" | xargs -I@ echo -select @ | xargs --no-run-if-empty perl /opt/fhem/contrib/commandref_join.pl 



init: 
	@echo $(SOURCES)
	@echo ${CURDIR_ESCAPED}

test_all: test_commandref deploylocal fhem_start |  ${SOURCES}
	@echo === TEST_ALL done ===

fhem_start: deploylocal
	cd /opt/fhem && perl fhem.pl fhem_ut.cfg && cd ${CURDIR_ESCAPED}
	@echo === ready for unit tests ===
fhem_kill:
	@echo === finished unit tests ===
	@sudo pkill -f -x "perl fhem.pl fhem*.cfg" || true

test:  | fhem_start test_all 
	@echo === running unit tests ===
	$(MAKE) 

