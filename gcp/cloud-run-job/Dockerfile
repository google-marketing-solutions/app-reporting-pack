# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
FROM google/cloud-sdk

RUN apt-get install -y python3-venv
ENV VENV=/opt/venv
RUN python3 -m venv $VENV
ENV PATH="$VENV/bin:$PATH"

WORKDIR /arp
COPY app/requirements.txt .
RUN python3 -m pip install -r requirements.txt --require-hashes --no-deps

# bake the application in (no GCS pull at runtime)
COPY app ./app
COPY gcp/cloud-run-job/main.sh ./main.sh
COPY gcp/settings.ini ./settings.ini
RUN chmod +x ./main.sh ./app/run-local.sh

ENTRYPOINT ["./main.sh"]
