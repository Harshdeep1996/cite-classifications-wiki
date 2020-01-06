# -*- coding: utf-8 -*-
"""
Extract metadata for wild examples which have been classified into journal/book.

Metadata is extracted asynchronously in order to do extraction for huge data.

For URL requests, there are multiple parameters such as
    1. interval - time in which a certain number of requests should be sent
    2. limit - number of requests to be sent in an interval
    3. interval rate - increase/decrease interval rate
    4. limit rate - increase/decrease limit as time goes on
"""

import os
import ast
import json
import time
import pickle
import aiohttp
import asyncio
import pandas as pd
from datetime import datetime, timedelta


STORE_PATH = '<path-to-folder-where-you-want-to-store-results-in-chunk>'

class RateLimitMemory:

    def __init__(self, interval=1, limit=20, update=True, interval_rate=1.1, limit_rate=0.9):
        self.tstamps = []
        self.interval = timedelta(seconds=interval)
        self.limit = limit
        self.update = update
        self.interval_rate = interval_rate
        self.limit_rate = limit_rate

        self.not_complete_tasks = []

    soft_limit = property(lambda self: self.limit * self.limit_rate)
    soft_interval = property(lambda self: self.interval * self.interval_rate)


async def download(rlm, session, url, params, fname):
    while len(rlm.tstamps) >= rlm.soft_limit:
        threshold = datetime.utcnow() - rlm.soft_interval
        rlm.tstamps = [dt for dt in rlm.tstamps if dt > threshold]
        await asyncio.sleep(1)

    print(f"Downloading {fname}!")
    rlm.tstamps.append(datetime.utcnow())
    async with session.get(url, params=params) as resp:
        if rlm.update:
            rlm.limit = int(resp.headers.get("X-Rate-Limit-Limit", rlm.limit))
            str_interval = resp.headers.get("X-Rate-Limit-Interval", None)
            if str_interval:
                rlm.interval = timedelta(seconds=int(str_interval.rstrip("s")))

        result = await resp.text()
        if resp.status != 200:
            print(f"Skipping {fname}:\n{result}")
            rlm.not_complete_tasks.append(fname)
        else:
            print(f'Writing it to file {fname}')
            result = json.loads(result)
            with open(fname, "w") as output_file:
                if len(result['message']['items']) > 0:
                    top_3_results = result['message']['items'][:3]
                    output_file.write(json.dumps(top_3_results))
                else:
                    no_result = {'message': 'No result was found in CrossRef'}
                    output_file.write(json.dumps(no_result))


async def perform_tasks(rlm, url, params, out_dir):
    async with aiohttp.ClientSession() as session:
        tasks = []
        for p_i in range(len(params)):
            ## Check if the file already exists in the path and if not then setup a stack
            fname = os.path.join(out_dir, '_{}'.format(str(params[p_i]['index'])) + ".json")
            if 'query.bibliographic' not in params[p_i] and 'query.author' not in params[p_i]:
                print('No need to query CrossRef since we do not have parameters for: {}'.format(params[p_i]['index']))
                with open(fname, "w") as output_file:
                    output_file.write(result)

            if not os.path.exists(fname):
                del params[p_i]['index']
                download_coroutine = download(rlm, session, url, params, fname)
                tasks.append(asyncio.ensure_future(download_coroutine))
        if tasks:
            await asyncio.wait(tasks)
        else:
            print("No download was required!")


def get_params(dataset):
    params = []
    for i in range(dataset.shape[0]):
        r_dict = dict()
        title_ = dataset.iloc[i]['title']
        r_dict['index'] = dataset.iloc[i]['index']
        if title_ is not None:
            r_dict['query.bibliographic'] = title_
        author = dataset.iloc[i]['first_author']
        if author is not None:
            r_dict['query.author'] = author
            params.append(r_dict)

    print('Constructed parameters for requests')
    return params


def main():
    dataset_name = '<path-to-wild-citations-which-need-to-be-queried>'
    c_size = 75
    chunk_counter = 0

    for chunk_ in pd.read_csv(dataset_name, chunksize=c_size):
        ## Get the params for the selected examples
        params = get_params(chunk_)
        url = "https://api.crossref.org/works/"
        rlm = RateLimitMemory(interval=5) ## Change them if needed to set up a longer interval for a longer download
        loop = asyncio.get_event_loop()
        loop.run_until_complete(perform_tasks(rlm, url, params, STORE_PATH))

        chunk_counter += 1
        print('Taking a break....')
        time.sleep(4) ## Refreshing the connection

        if chunk_counter % 10 == 0:
            time.sleep(10)


if __name__ == '__main__':
    main()
