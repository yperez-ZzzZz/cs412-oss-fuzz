git clone https://github.com/yperez-ZzzZz/cs412-oss-fuzz.git && cd cs412-oss-fuzz/oss-fuzz
yes | python3 infra/helper.py build_image libpng
python3 infra/helper.py build_fuzzers libpng

# store results to build/out/corpus/
mkdir build/out/corpus/
python3 infra/helper.py run_fuzzer libpng libpng_read_fuzzer --corpus-dir build/out/corpus/