import os,json
from app.utils import CommonUtilsConstants
from app.utils.LogUtils import logger

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE_PATH = os.path.join(CURRENT_DIR, CommonUtilsConstants.CONFIG_FILE_PATH)

#Config File Loader
def get_config():
    try:
        logger.info("Fetching Configs")
        with open(CONFIG_FILE_PATH) as config_file:
            config = json.load(config_file)
            return config
    except Exception as e:
        raise Exception("ERROR::Unable to fetch configs", str(e))