#!/usr/bin/python3
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import io
import sys
import json
import ijson
import atheris


def TestOneInput(data):
  for parser_type in ['yajl2_c', 'yajl2_cffi', 'yajl2', 'yajl', 'python']:
    try:
      backend = ijson.get_backend(parser_type)
    except:
      # If we can't get the backend, just continue to the next.
      continue
    try:
      parse_items = backend.parse(io.BytesIO(data))
      for obj in ijson.items(parse_items, 'item'):
        pass
    except (
      ijson.common.JSONError,
      json.JSONDecodeError
    ):
      pass


def main():
  atheris.instrument_all()
  atheris.Setup(sys.argv, TestOneInput)
  atheris.Fuzz()


if __name__ == "__main__":
  main()
