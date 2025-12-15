import os
import json
import pandas as pd
from multiprocessing import Pool, Manager
import itertools
import time
from pathlib import Path

# Set directories relative to the script's location
BASE_DIR = Path(__file__).resolve().parent
INPUT_DIRECTORY = BASE_DIR / 'Data/propertyDetailsgurgaon'
OUTPUT_DIRECTORY = BASE_DIR / 'Data'

# List of all JSON files
file_names = [
    os.path.join(INPUT_DIRECTORY, property)
    for property in os.listdir(INPUT_DIRECTORY) if property.endswith('.json')
]


COLUMNS = [
    "localityName",
    "landMarks",
    "locality",
    "price",
    "nameOfSociety",
    "projectName",
    "carpetArea",
    "coveredArea",
    "coveredAreaUnit",
    "carpetAreaSqft",
    "possessionStatus",
    "floorNumber",
    "totalFloorNumber",
    "longitude",
    "latitude",
    "transactionType",
    "facing",
    "ownershipType",
    "furnished",
    "bedrooms",
    "bathrooms",
    "numberOfBalconied",
    "propertyType",
    "additionalRooms",
    "ageofcons",
    "isVerified",
    "listingTypeDesc",
    "propertyAmenities",
    "facilitiesDesc",
    "propertyId",
    "url",
    "psmUsp",
    "shortAddress"
]

# Function to process a single JSON file
def process_file(file_path):
    try:
        temp = {column: [] for column in COLUMNS}
        
        with open(file_path, 'r', encoding='utf-8') as json_file:
            data = json.load(json_file).get('propertyDetailInfoBeanData')
        
        if data is not None:
            try:
                for column in COLUMNS:
                    temp[column].append(data.get('propertyDetail').get('detailBean').get(column))
            except Exception as e:
                print(f"Error processing column {column} with file_path {file_path}: {e}")
        else:
            print(f"\n\nNo data found in {file_path}\n\n")
            return None
        
        # print(f"Processing done for {file_path}")

        # Convert to DataFrame and return
        return pd.DataFrame(temp)

    except Exception as e:
        print(f"\n\nError processing file {file_path}: {e}\n\n")
        return None

# Function to process files in batches
def process_batch(batch_files):
    batch_results = []
    for file_path in batch_files:
        # print(f"Processing file {file_path}")
        result = process_file(file_path)
        if result is not None:
            batch_results.append(result)
    print(f"Batch processing done for {len(batch_results)} files")
    return batch_results

# Function to process files using multiprocessing
def process_files_in_batches(file_names, batch_size=1000, num_workers=4):
    # Split files into batches
    # print('splitting files into batches')
    batches = [file_names[i:i + batch_size] for i in range(0, len(file_names), batch_size)]
    # print(f"Total batches: {len(batches)}")

    with Manager() as manager:  # noqa: F841
        print('manager created')
        with Pool(processes=num_workers) as pool:
            print('pool created')
            results = pool.map(process_batch, batches)
        print('pool processing completed')
        # Flatten the results and concatenate
        all_results = list(itertools.chain.from_iterable(results))
        print('all results collected')
        return pd.concat(all_results, ignore_index=True) if all_results else pd.DataFrame()

if __name__ == '__main__':
    start = time.time()
    # Adjust batch size and number of workers as needed
    df = process_files_in_batches(file_names, batch_size=1000, num_workers=4)

    # Save the DataFrame to a CSV or other format
    output_path = os.path.join(OUTPUT_DIRECTORY, 'gurgaonRawExtractedPropertyDetails.csv')
    df.to_csv(output_path, index=False)
    print(f"Data processing complete. Output saved to {output_path}!, took time: {time.time() - start}")