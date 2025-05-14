git clone -b w_o_corpus https://github.com/yperez-ZzzZz/cs412-oss-fuzz.git
cd cs412-oss-fuzz/oss-fuzz
yes | python3 infra/helper.py build_image libpng
python3 infra/helper.py build_fuzzers libpng

# store results to build/out/corpus_w_o/
mkdir build/out/corpus_w_o/
python3 infra/helper.py run_fuzzer libpng libpng_read_fuzzer --corpus-dir build/out/corpus_w_o/