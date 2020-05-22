Host tests to run on UNIX platforms

Manual Pytest wrappers that return 0 on success and non-zero if test failed

Build is using a top level makefile that traverses test subdirectories and
builds each test

To run all tests in virtual environment I might do:

  make clean all
  ../../.venv/bin/pytest -s

I've also added a __main__ trigger, so I can invoke the test script outside of
virtual environment:

  make clean all
  find . -name test_\*.py | while read f ; do \
    ( cd `dirname $f` ; python `basename $f` ) || break ; done
