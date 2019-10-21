UnitTest - FHEM Module
======


FHEM Module for developers who want to run unittests



How to install
======
The Perl modules can be loaded directly into your FHEM installation:

```update all https://raw.githubusercontent.com/RFD-FHEM/UnitTest/master/controls_unittest.txt```

How To use this?
=====

Usage of the unitTest Module isn't very complex, but needs some basic understanding of unittests.

An example can be found unter tests/test_modules-definition.txt

Because the unittest runs as a normal fhem operation the test and the code is defined as usaual for FHEM:

```
defmod test_modules UnitTest global (
 {
	my @modulesToTest=qw/98_DOIF.pm 98_DOIFtools.pm 33_readingsGroup.pm/; 
	
 	subtest 'Syntax Check Modules ' => sub {
		plan tests => scalar @modulesToTest;
		for my $module (@modulesToTest)
		{
			my $returncode = CommandReload(undef,$module);
			is($returncode, undef, "check $module ");
		};
	}; 

 };
);
```
What does this test do?
It is a very basic thing, it will verify the syntax of three modules; 98_DOIF.pm, 98_DOIFtools.pm and 33_readingsGroup.pm.
But be careful in combination with [Devel::Cover](https://metacpan.org/pod/Devel::Cover#Redefined-subroutines "Meta::cpan"), this test reloads the modules and causes a redefinment of all subs. So name such a test exactly "test_modules" and the makefile will run this test as the first one!

Variable recovery
=====
Just before starting the test, the hash of the definition under test is stored and recovered after the test.
So leving a test will restore the hash of the definition as it was before.

More Information
=====
Look at the source code of the module or some examples in the RFFHEM Repository
