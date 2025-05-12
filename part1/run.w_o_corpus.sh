git clone https://github.com/yperez-ZzzZz/cs412-oss-fuzz/tree/w_o_corpus && cd cs412-oss-fuzz/oss-fuzz
python3 infra/helper.py build_image libpng
python3 infra/helper.py build_fuzzers libpng

# store results to build/out/corpus
mkdir build /out/corpus_w_o/
python3 infra/helper.py run_fuzzer libpng libpng_read_fuzzer --corpus-dir build/out/corpus_w_o/

# generate coverage
python3 infra/helper.py build_fuzzers --sanitizer coverage libpng
python3 infra/helper.py coverage libpng --corpus-dir build/out/corpus_w_o/ --fuzz-target libpng_read_fuzzer