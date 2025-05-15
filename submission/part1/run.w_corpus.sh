#!/bin/bash
# RUN THIS SCRIPT IN AN EMPTY FOLDER
# MAKE SURE THAT NO OTHER HTTP SERVER IS RUNNING ON PORT 8008 TO SEE THE COVERAGE REPORT
# YOU NEED TO RUN WITH sudo IF with_seeds=false

branch=libpng16
folder=fuzzer_ORIGINAL

with_seeds=true # if this is false, you need to run the script with sudo
fuzz_time_in_seconds=14400 # four hours in seconds

# create new directories
mkdir $folder
cd $folder

# setup fuzzers

# clone libpng fork
git clone https://github.com/yperez-ZzzZz/libpng-better.git -b $branch libpng

# clone oss-fuzz
git clone https://github.com/google/oss-fuzz.git

# cd into oss-fuzz
cd oss-fuzz

# create cli (makes useful commands)
# If you want to see its contents, look at file after running this script
printf '#!/bin/bash\n\ncommand=$1\n\necho $0\n\n# start fuzzing\nif [ "$command" == "fuzz" ]; then\n\nbash $0 build_fuzz\nbash $0 nbfuzz\n\nfi\n\n# start fuzzing without rebuilding\nif [ "$command" == "nbfuzz" ]; then\n\npython3 infra/helper.py run_fuzzer libpng libpng_read_fuzzer --corpus-dir build/corpus\n\nfi\n\n# make coverage report\nif [ "$command" == "coverage" ]; then\n\npython3 infra/helper.py build_fuzzers --sanitizer coverage libpng ../libpng/\npython3 infra/helper.py coverage libpng --corpus-dir build/corpus/ --fuzz-target libpng_read_fuzzer --no-corpus-download\n\nfi\n\n# build image and fuzzers\nif [ "$command" == "build" ]; then\n\npython3 infra/helper.py build_image libpng\nbash $0 build_fuzz\n\nfi\n\n# build image and fuzzers\nif [ "$command" == "build_first" ]; then\n\npython3 infra/helper.py build_image libpng --pull\nbash $0 build_fuzz\n\nfi\n\n# fuzzer\nif [ "$command" == "build_fuzz" ]; then\n\nrm -rf -d build/corpus/ # remove previous corpus\npython3 infra/helper.py build_fuzzers libpng ../libpng/\nmkdir build/corpus\n\nfi\n\n# fuzz for N seconds (N is the second arguments)\nif [ "$command" == "timed_nbfuzz" ]; then\n\npython3 infra/helper.py run_fuzzer libpng libpng_read_fuzzer --corpus-dir build/corpus -e FUZZER_ARGS="-max_total_time=$2 -rss_limit_mb=2560 -timeout=25 -fork=1 -ignore_crashes=1"\n\nfi\n\n\n# fuzz for N seconds (N is the second arguments)\nif [ "$command" == "timed_fuzz" ]; then\n\nbash $0 build_fuzz\nbash $0 timed_nbfuzz\n\nfi\n' > cli


# build the project for a first time
bash cli build_first

# build fuzzer
bash cli build_fuzz

# remove corpus if required
if [ "$with_seeds" = false ] ; then
    sudo rm build/out/libpng/libpng_read_fuzzer_seed_corpus.zip
fi

# run fuzzer
bash cli timed_nbfuzz $fuzz_time_in_seconds

# get coverage report
bash cli coverage
