"""
Fivetran Connector SDK — JSONPlaceholder Users Pipeline
Fetches users from https://jsonplaceholder.typicode.com/users
and syncs them into the destination warehouse via Fivetran.

Deploy with:
  fivetran deploy --api-key <KEY> --api-secret <SECRET> --connection <CONNECTION_ID>
"""

import requests
from fivetran_connector_sdk import Connector
from fivetran_connector_sdk import Operations as op
from fivetran_connector_sdk import Logging as log

SOURCE_URL = "https://jsonplaceholder.typicode.com/users"


def schema(configuration: dict):
    """
    Define the destination table schema.
    Fivetran uses this to create/validate the table before syncing.
    """
    return [
        {
            "table": "users",
            "primary_key": ["id"],
            "columns": {
                "id":       "INT",
                "name":     "STRING",
                "username": "STRING",
                "email":    "STRING",
                "phone":    "STRING",
                "website":  "STRING",
                # Nested address fields flattened
                "address_street":   "STRING",
                "address_suite":    "STRING",
                "address_city":     "STRING",
                "address_zipcode":  "STRING",
                "address_lat":      "STRING",
                "address_lng":      "STRING",
                # Nested company fields flattened
                "company_name":         "STRING",
                "company_catch_phrase": "STRING",
                "company_bs":           "STRING",
            },
        }
    ]


def update(configuration: dict, state: dict):
    """
    Main sync function. Called by Fivetran on every scheduled sync.

    - configuration: values from the connector setup form (unused here — public API)
    - state: checkpoint state from the previous sync (unused — full refresh each time)
    """
    log.info(f"Starting sync from {SOURCE_URL}")

    try:
        response = requests.get(SOURCE_URL, timeout=30)
        response.raise_for_status()
        users = response.json()
    except requests.exceptions.RequestException as e:
        log.severe(f"Failed to fetch users from source API: {e}")
        raise

    log.info(f"Fetched {len(users)} users from source API")

    for user in users:
        address = user.get("address", {})
        geo     = address.get("geo", {})
        company = user.get("company", {})

        # Upsert each user row into the destination table
        yield op.upsert(
            table="users",
            data={
                "id":       user["id"],
                "name":     user.get("name"),
                "username": user.get("username"),
                "email":    user.get("email"),
                "phone":    user.get("phone"),
                "website":  user.get("website"),
                # Flattened address
                "address_street":  address.get("street"),
                "address_suite":   address.get("suite"),
                "address_city":    address.get("city"),
                "address_zipcode": address.get("zipcode"),
                "address_lat":     geo.get("lat"),
                "address_lng":     geo.get("lng"),
                # Flattened company
                "company_name":         company.get("name"),
                "company_catch_phrase": company.get("catchPhrase"),
                "company_bs":           company.get("bs"),
            },
        )

    # Checkpoint — tells Fivetran the sync completed successfully
    yield op.checkpoint(state={})
    log.info("Sync complete — checkpoint saved")


# Required: Connector object wiring schema + update functions
connector = Connector(update=update, schema=schema)

if __name__ == "__main__":
    # Local test run — simulates a Fivetran sync without deploying
    connector.debug()
