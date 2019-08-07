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

En example can be found unter tests/test_modules-definition.txt

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
What does dies test do?
It is a very basic thing, it will verify the syntax of three modules; 98_DOIF.pm, 98_DOIFtools.pm and 33_readingsGroup.pm.



More Information
=====
Look at the source code of the module or some examples in the RFFHEM Repository
