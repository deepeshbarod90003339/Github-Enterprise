import asyncio
import aiohttp
from typing import Optional
from app.utils import CommonUtils,CommonUtilsConstants as CUC
from app.utils.LogUtils import logger
from app.utils.getconfig import get_config

#get current config
config = get_config()

class VaultClient:
    def __init__(self):
        self.base_url = f"{config.get(CUC.URL_KEY)}v1"
        self.namespace = config.get(CUC.NAMESPACE_KEY,"")
        self.role_id = config.get(CUC.ROLE_ID_KEY,"")
        self.secret_id = config.get(CUC.SECRET_ID_KEY,"")
        self._token: Optional[str] = None
        self._lock = asyncio.Lock()  # Prevent concurrent auth calls
        self._session: Optional[aiohttp.ClientSession] = None        
        logger.info("VaultClient initialized")


    async def _get_session(self) -> aiohttp.ClientSession:
        if not self._session or self._session.closed:
            timeout = aiohttp.ClientTimeout(total=30)
            connector = aiohttp.TCPConnector(limit=50)  # controls concurrent connections
            self._session = aiohttp.ClientSession(timeout=timeout, connector=connector)
            logger.info("Created new aiohttp ClientSession for VaultClient")
        return self._session

    async def _authenticate(self):
        """
        Authenticate with Vault using AppRole.
        Uses a lock to prevent multiple concurrent auth requests.
        """
        async with self._lock:
            # Another coroutine might have already refreshed the token
            if self._token:
                return self._token

            session = await self._get_session()
            url = f"{self.base_url}/auth/approle/login"
            headers = {"X-Vault-Namespace": self.namespace}
            payload = {"role_id": self.role_id, "secret_id": self.secret_id}

            async with session.post(url, json=payload, headers=headers) as resp:
                if resp.status != 200:
                    body = await resp.text()
                    raise Exception(f"Vault authentication failed: {resp.status} - {body}")
                data = await resp.json()
                self._token = data["auth"]["client_token"]
                logger.info("Vault authentication successful")
                return self._token

    async def _ensure_token(self):
        """
        Ensures that a valid token exists before any Vault request.
        """
        if not self._token:
            await self._authenticate()
            logger.info("Vault token ensured")

    async def read_secret(self, path: str, environment: str):
        """
        Read secret from Vault KV v2 with concurrency safety.
        """
        await self._ensure_token()
        session = await self._get_session()
        mount_point = CommonUtils.get_secret_engine(environment)
        url = f"{self.base_url}/{mount_point}/data/{path}"
        headers = {
            "X-Vault-Token": self._token,
            "X-Vault-Namespace": self.namespace,
        }

        async with session.get(url, headers=headers) as resp:
            if resp.status == 403:
                # Token might be expired — reauthenticate once
                self._token = None
                logger.info("Vault token expired, reauthenticating")
                await self._authenticate()
                logger.info("Reauthentication successful, retrying secret read")
                return await self.read_secret(path, environment)
            elif resp.status != 200:
                body = await resp.text()
                raise Exception(f"Failed to read secret: {resp.status} - {body}")
            
            data = await resp.json()
            logger.info(f"Secret read successfully from path: {path}")
            return data["data"]["data"]

    async def close(self):
        """
        Close the aiohttp session cleanly on app shutdown.
        """
        if self._session and not self._session.closed:
            logger.info("Closing VaultClient aiohttp session")
            await self._session.close()


# Singleton instance
vault_client = VaultClient()
