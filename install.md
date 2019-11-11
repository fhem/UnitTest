# Running unittests # 

To run unittests a Test enviroment is needed. 

- Fhem installation in /opt/fhem
- Experience in perl
- Knowledge of Test::More 

### Requirements for 98_UnitTest.pm ###

You should not run the UnitTests on a productive used fhem installation.


1. install required test modules via `cpan Test::Device::SerialPort` `cpan Mock::Sub` and `cpan Test::More`  
On Systems with low memory, use [cpanm](https://metacpan.org/pod/App::cpanminus)
 for installing the packages.

2. You can use make for running the tests. There is a makefile which will prepare your fhem installation for running the tests.
- stop any running fhem instance
- copy the module into the fhem  directory /opt/fhem/FHEM
- copy a minimal config file for fhem fhem_ut.cfg and start fhem with this configfile.
- run the tests in the tests directory. They must be named <name of test>-definition.txt
- cleans up logfiles
- stop fhem

 


Now you can start defining a unittest

```
cd /opt/fhem
perl fhem.pl fhem.cfg
```


### Requirements for test-runner.sh ### 
You can run tests from the commandline. Make will do this for you automatic

Currently test-runner searches logfiles in /opt/fhem. So you can install your test instance of fhem into a separate directoy but you must link the logfile to /opt/fhem  
Unit Testfiles are searched in the directory test.  

If you call `test-runer.sh my_test_1` then this will try to load a file test/my_test_1-definition.


