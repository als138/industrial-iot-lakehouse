# Superset-Dremio datetime64[ms] Error Fix

## Problem Description

When connecting Apache Superset to Dremio using the SQLAlchemy Dremio connector, you may encounter the following error:

```
'datetime64[ms]' for timestamp field
```

This error occurs because the SQLAlchemy Dremio connector doesn't have proper type mappings for pandas datetime64 types, specifically `datetime64[ms]` (millisecond precision timestamps).

## Root Cause

The issue was in the type mapping dictionaries in the SQLAlchemy Dremio connector files:
- `sqlalchemy_dremio-master/sqlalchemy_dremio/base.py`
- `sqlalchemy_dremio-master/sqlalchemy_dremio/query.py`

These files were missing mappings for various `datetime64` types that pandas uses internally.

## Solution Applied

### 1. Updated Type Mappings

Added comprehensive datetime64 type mappings to both files:

```python
'datetime64[ns]': types.DATETIME,  # nanosecond precision
'datetime64[ms]': types.DATETIME,  # millisecond precision  
'datetime64[us]': types.DATETIME,  # microsecond precision
'datetime64[s]': types.DATETIME,   # second precision
```

### 2. Fixed Superset Container Configuration

Updated `docker-compose.yml` to properly install the SQLAlchemy Dremio connector in the Superset container:

```yaml
superset:
  image: apache/superset:latest
  container_name: superset
  ports:
    - "8088:8088"
  environment:
    - SUPERSET_SECRET_KEY=your_secret_key_here
  volumes:
    - superset_data:/app/superset_home
    - ./sqlalchemy_dremio-master:/app/sqlalchemy_dremio-master
  command: >
    /bin/bash -c "
    pip install --upgrade 'SQLAlchemy~=2.0.41' &&
    pip install --upgrade 'pyarrow~=20.0.0' &&
    pip install --no-build-isolation --no-deps /app/sqlalchemy_dremio-master &&
    superset db upgrade &&
    superset fab create-admin
      --username admin
      --firstname Superset
      --lastname Admin
      --email admin@superset.com
      --password admin &&
    superset init &&
    /usr/bin/run-server.sh
    "
```

## Files Modified

1. **sqlalchemy_dremio-master/sqlalchemy_dremio/base.py**
   - Added datetime64 type mappings to `_type_map` dictionary

2. **sqlalchemy_dremio-master/sqlalchemy_dremio/query.py**
   - Added datetime64 type mappings to `_type_map` dictionary

3. **docker-compose.yml**
   - Enabled the command to install SQLAlchemy Dremio connector
   - Added automatic admin user creation

## How to Apply the Fix

### Option 1: Use the Automated Script

```bash
./fix-superset-dremio-datetime.sh
```

### Option 2: Manual Steps

1. Stop all containers:
   ```bash
   docker-compose down
   ```

2. Remove Superset volume for clean installation:
   ```bash
   docker volume rm industrial-iot-lakehouse_superset_data
   ```

3. Start containers with updated configuration:
   ```bash
   docker-compose up -d
   ```

4. Wait for services to initialize (30-60 seconds)

## Verification

After applying the fix:

1. **Access Superset**: http://localhost:8088
   - Username: `admin`
   - Password: `admin`

2. **Add Dremio Database Connection**:
   - Database: `dremio`
   - SQLAlchemy URI: `dremio://dremio:32010`

3. **Test with timestamp fields**: Create charts using tables with timestamp columns

## Expected Behavior

- ✅ No more `'datetime64[ms]'` errors
- ✅ Timestamp fields display correctly in Superset
- ✅ Charts and dashboards work with time-based data
- ✅ All datetime64 precision levels supported (ns, ms, us, s)

## Troubleshooting

If you still encounter issues:

1. **Check container logs**:
   ```bash
   docker-compose logs -f superset
   docker-compose logs -f dremio
   ```

2. **Verify SQLAlchemy Dremio installation**:
   ```bash
   docker-compose exec superset pip list | grep sqlalchemy
   ```

3. **Test connection manually**:
   ```bash
   docker-compose exec superset python -c "
   from sqlalchemy_dremio.query import _type_map
   print('datetime64[ms]' in _type_map)
   "
   ```

## Additional Notes

- The fix supports all common datetime64 precision levels used by pandas
- The SQLAlchemy Dremio connector is now properly installed in the Superset container
- Admin user is automatically created for easier setup
- The fix is backward compatible with existing data 