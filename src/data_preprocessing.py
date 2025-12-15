import pandas as pd
from pathlib import Path
import joblib
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, RobustScaler
import category_encoders as ce
import logging
from sklearn import set_config



# set the transformer outputs to pandas
set_config(transform_output='pandas')

# columns to preprocess in data
ohe_encode = ['transactiontype','region','propertytype','furnished','ageofcons']
target_encode = ['locality']
robust_scaling = ['bedrooms','bathrooms','balconies','superbuiltupareasqft', 'totalfloornumber']


target_col = 'price'

# create logger
logger = logging.getLogger("data_preprocessing")
logger.setLevel(logging.DEBUG)


# console handler
handler = logging.StreamHandler()
handler.setLevel(logging.DEBUG)

# file handler
file_handler = logging.FileHandler('data_preprocessing.log')
file_handler.setLevel(logging.ERROR)


# add handler to logger
logger.addHandler(handler)

# create a fomratter
formatter = logging.Formatter(fmt='[%(asctime)s] (line %(lineno)d) - %(name)s - %(levelname)s in %(module)s: %(message)s')
# add formatter to handler
handler.setFormatter(formatter)
file_handler.setFormatter(formatter)


# load data
def load_data(data_path: Path) -> pd.DataFrame:
    try:
        df = pd.read_csv(data_path)
        
    except FileNotFoundError:
        logger.error("The file to load does not exist")
        raise
        
    return df



def save_transformer(transformer, save_dir: Path, transformer_name: str) -> None:
   # form the save location
   save_location = save_dir / transformer_name
   
   # save the transformer
   joblib.dump(value=transformer, filename=save_location)
   
   
def train_preprocessor(preprocessor,X_train: pd.DataFrame, y_train: pd.DataFrame):
    
    # fit the preprocessor
    preprocessor.fit(X_train, y_train)
    
    return preprocessor


def perform_transformations(preprocessor, data: pd.DataFrame) -> None:
    
    # transform the data
    transformed_data = preprocessor.transform(data)
    
    return transformed_data



def save_data(data: pd.DataFrame, save_path: Path) -> None:
    data.to_csv(save_path, index=False)
    
    

def make_X_and_y(data: pd.DataFrame, target: str) -> tuple:
    X = data.drop(columns=[target])
    y = data[target]
    
    return X, y
    
def join_X_and_y(X: pd.DataFrame, y: pd.Series):
    # join based on indexes
    joined_df = X.join(y,how='inner')
    return joined_df



if __name__ == '__main__':
    # paths
    # root path
    root_path = Path(__file__).parent.parent
    # data load path
    train_data_path = root_path / "data" / "interim" / "train.csv"
    test_data_path = root_path / "data" / "interim" / "test.csv"
    
    # save data directory
    save_data_dir = root_path / "data" / "processed"
    
    # make dir if not present
    save_data_dir.mkdir(exist_ok=True, parents=True)
    
    # train and test dataz save paths
    # filenames
    train_trans_filename = "train_trans.csv"
    test_trans_filename = "test_trans.csv"
    
    # save paths
    train_trans_save_path = save_data_dir / train_trans_filename
    test_trans_save_path = save_data_dir / test_trans_filename
    
    #Columns Transformer
    columns_transformer = ColumnTransformer(
                        transformers=[
                            ("ohe", OneHotEncoder(drop="first", handle_unknown="ignore", sparse_output=False), ohe_encode),
                            ("robust", RobustScaler(), robust_scaling)
                        ], remainder="passthrough", n_jobs=-1, force_int_remainder_cols=False,verbose_feature_names_out=False
                        )
    
    # Creating a pipeline 
    preprocessor = Pipeline([
                    ('target_encoder', ce.TargetEncoder(cols=target_encode)),
                    ('preprocessor', columns_transformer)
                    
                    ])
    
    # load the train and test data
    train_df = load_data(data_path=train_data_path)
    logger.info("Train data loaded successfully")
    test_df = load_data(data_path=test_data_path)
    logger.info("Test data loaded successfully")
    
    
    # Split the train and test data
    
    X_train, y_train = make_X_and_y(data=train_df, target=target_col)
    X_test, y_test = make_X_and_y(data=test_df, target=target_col)
    logger.info("Data splitting completed")
    
    # train the preprocessor
    train_preprocessor(preprocessor=preprocessor, X_train=X_train, y_train=y_train)
    logger.info("Preprocessor trained successfully")
    
    # transform the data
    X_train_trans = perform_transformations(preprocessor=preprocessor, data=X_train)
    logger.info("Train data transformed successfully")
    
    X_test_trans = perform_transformations(preprocessor=preprocessor, data=X_test)
    logger.info("Test data transformed successfully")
    
    
    # join back X and y
    train_trans_df = join_X_and_y(X=X_train_trans, y=y_train)
    test_trans_df = join_X_and_y(X=X_test_trans, y=y_test)
    logger.info("Datasets joined")
    
    
    # save the tranformed data
    data_subsets = [train_trans_df, test_trans_df]
    data_paths = [train_trans_save_path,test_trans_save_path]
    filename_list = [train_trans_filename, test_trans_filename]
    for filename , path, data in zip(filename_list, data_paths, data_subsets):
        save_data(data=data, save_path=path)
        logger.info(f"{filename.replace(".csv","")} data saved to location")
    
    
    # save the preprocessor to location
    # tranformer name
    
    transformer_filename = "preprocesser.joblib"
    # directory to save tranformers
    
    transformer_save_dir = root_path / "models"
    transformer_save_dir.mkdir(exist_ok=True)
    # save the transformer
    save_transformer(transformer=preprocessor,
                     save_dir=transformer_save_dir,
                     transformer_name=transformer_filename)
    logger.info("Preprocessor saved to location")