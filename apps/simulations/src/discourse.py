import os
import json
import requests
from requests.exceptions import RequestException
import time

# Fetch the JSON data
# Define the URL and the file path
url = 'https://forum.arbitrum.foundation/c/proposals/7.json'
file_path = '/Users/arnold/Development/lighthouse.cx/signals-poc/apps/simulations/src/proposals_data.json'

# Check if the data file already exists
def get_topics(url, file_path):
  if os.path.exists(file_path):
    with open(file_path, 'r') as file:
      topics = json.load(file)
  else:
    topics = []
    page = 1
    backoff_time = 1  # Start with 1 second backoff

    while True:
      try:
        response = requests.get(url, params={'page': page})
        response.raise_for_status()
        page_data = response.json()

        # Check if there are no more topics
        if not page_data['topic_list']['topics']:
          break

        # Extend the topics list
        topics.extend(page_data['topic_list']['topics'])
        print(f"Fetched {len(page_data['topic_list']['topics'])} topics from page {page}")
        page += 1
        backoff_time = 1  # Reset backoff time on success

      except RequestException as e:
        print(f"Request failed: {e}. Retrying in {backoff_time} seconds...")
        time.sleep(backoff_time)
        backoff_time = min(backoff_time * 2, 60)  # Exponential backoff with a cap

    # Write the data to the file
    with open(file_path, 'w') as file:
      json.dump(topics, file)

  return topics

