Tests of device-side flash-related functionality

These run on hardware and so are manually executed rather than using Pytest
Build is using Waf with a customised top level script that traverses test
subdirectories and builds each test

Some require the Data Partition Generator (DPG) utility from Flash Data
Partition library, eg:

  PATH+=:../../../lib_flash_data_partition/host/data_partition_generator/bin
  export PATH

Note that a flash specification is passed to the DPG, but since the tests never
read it back, it can be any

Normally, there will be a shell script in each test directory that shows how
to run the test

Convention is that pass is when last line of test output is 'PASS'

Build is using Waf with a customised top level script that traverses test
subdirectories and builds each test

To build and run all tests I might do:

  waf configure clean build

  find . -name run.sh | while read f ; do \
    ( cd `dirname $f` ; sh -x run.sh ) || break ; done
