import pandas as pd
from sklearn.model_selection import train_test_split
import yaml
import logging
from pathlib import Path





# create logger
logger = logging.getLogger("data_preparation")
logger.setLevel(logging.DEBUG)

# console handler
handler = logging.StreamHandler()
handler.setLevel(logging.DEBUG)

# file handler
file_handler = logging.FileHandler('data_preparation.log')
file_handler.setLevel(logging.DEBUG)


# create a fomratter
formatter = logging.Formatter(fmt='[%(asctime)s] (line %(lineno)d) - %(name)s - %(levelname)s in %(module)s: %(message)s')
# add formatter to handler
handler.setFormatter(formatter)
file_handler.setFormatter(formatter)

# ADD BOTH HANDLERS
logger.addHandler(handler)
logger.addHandler(file_handler)



def load_data(data_path: Path, columns: list=['propertytype',
                                              'region',
                                              'locality',
                                              'bedrooms',
                                              'bathrooms',
                                              'balconies',
                                              'superbuiltupareasqft',
                                              'transactiontype',
                                              'ageofcons',
                                              'furnished',
                                              'additionalRooms',
                                              'totalfloornumber',
                                              'price',]) -> pd.DataFrame:
    try:
        df = pd.read_csv(data_path, usecols=columns)
        df.drop_duplicates(inplace=True)

        
    except FileNotFoundError:
        logger.error("The file to load does not exist")
        raise
        
    return df

def split_data(data: pd.DataFrame, test_size: float, random_state: int):
    train_data, test_data = train_test_split(data, test_size=test_size, random_state=random_state)
    return train_data, test_data


def read_params(file_path: Path) -> dict:
    with open(file_path, "r") as yaml_file:
        params_file = yaml.safe_load(yaml_file)
        
    return params_file

def save_data(data: pd.DataFrame, save_path: Path) -> None:
    data.to_csv(save_path, index=False)
    
    


if __name__ == "__main__":
    # set file paths
    # root path
    
    root_path = Path(__file__).parent.parent
    # data load path
    data_path = root_path / "data" / "raw" / "real_estate.csv"
    # save data directory
    save_data_dir = root_path / "data" / "interim" 
    
    # make dir if not present
    save_data_dir.mkdir(exist_ok=True, parents=True)
    
    # train and test data save paths
    # filenames
    
    train_filename = "train.csv"
    test_filename = "test.csv"
    # save path for train and test
    save_train_path = save_data_dir / train_filename
    save_test_path = save_data_dir / test_filename
    
    # parameters file
    params_file_path = root_path / "params.yaml"
    
    # load the data
    df = load_data(data_path)
    logger.info("Data loaded Successfully")
    
    # read the parameters
    parameters = read_params(params_file_path)['Data_Preparation']
    test_size = parameters['test_size']
    random_state = parameters['random_state']
    logger.info("Parameters read Successfully")
    
    
    # split into train and test data
    train_data, test_data = split_data(df, test_size=test_size, random_state=random_state)
    logger.info("Dataset splited into train and test data")
    
    
    # save the train and test data
    data_subsets =[train_data, test_data]
    data_paths = [save_train_path,save_test_path]
    filename_list = [train_filename, test_filename]
    
    for filename, path, data in zip(filename_list, data_paths, data_subsets):
        save_data(data=data, save_path = path)
        logger.info(f"{filename.replace(".csv","")} data saved to location")