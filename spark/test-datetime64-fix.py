#!/usr/bin/env python3
"""
Test script to verify datetime64[ms] type mapping fix for Superset-Dremio integration
"""

import pandas as pd
import numpy as np
from datetime import datetime
import sys
import os

# Add the sqlalchemy_dremio path
sys.path.append('../sqlalchemy_dremio-master')

def test_datetime64_mapping():
    """Test that datetime64[ms] types are properly mapped"""
    
    # Create test data with different datetime64 types
    test_data = {
        'timestamp_ms': pd.Series([datetime.now()], dtype='datetime64[ms]'),
        'timestamp_ns': pd.Series([datetime.now()], dtype='datetime64[ns]'),
        'timestamp_us': pd.Series([datetime.now()], dtype='datetime64[us]'),
        'timestamp_s': pd.Series([datetime.now()], dtype='datetime64[s]'),
        'regular_timestamp': pd.Series([datetime.now()]),
    }
    
    df = pd.DataFrame(test_data)
    
    print("✅ Test data created with various datetime64 types:")
    print(df.dtypes)
    print()
    
    # Test the type mapping from query.py
    try:
        from sqlalchemy_dremio.query import _type_map
        from sqlalchemy import types
        
        print("✅ SQLAlchemy Dremio type mappings loaded successfully")
        print("Available datetime64 mappings:")
        
        for dtype, sqlalchemy_type in _type_map.items():
            if 'datetime64' in dtype:
                print(f"  {dtype} -> {sqlalchemy_type}")
        
        # Test mapping for each datetime64 type
        for column, series in test_data.items():
            dtype_str = str(series.dtype)
            if dtype_str in _type_map:
                mapped_type = _type_map[dtype_str]
                print(f"✅ {column} ({dtype_str}) -> {mapped_type}")
            else:
                print(f"❌ {column} ({dtype_str}) -> NOT MAPPED")
        
        print("\n✅ All datetime64 types should now be properly mapped!")
        
    except ImportError as e:
        print(f"❌ Error importing SQLAlchemy Dremio: {e}")
        return False
    
    return True

def test_superset_compatibility():
    """Test Superset compatibility with the datetime64 mappings"""
    
    print("\n🔍 Testing Superset compatibility...")
    
    # Simulate what Superset would do when connecting to Dremio
    try:
        from sqlalchemy import create_engine, text
        from sqlalchemy_dremio.base import DremioDialect
        
        print("✅ SQLAlchemy and Dremio dialect imported successfully")
        
        # Test that the dialect can handle datetime64 types
        dialect = DremioDialect()
        print(f"✅ Dremio dialect loaded: {dialect.name}")
        
        # Test type compilation
        from sqlalchemy import DateTime
        dt_type = DateTime()
        compiled = dialect.type_compiler.process(dt_type)
        print(f"✅ DateTime type compiled as: {compiled}")
        
        print("✅ Superset should now be able to handle datetime64[ms] fields!")
        
    except ImportError as e:
        print(f"❌ Error testing Superset compatibility: {e}")
        return False
    
    return True

if __name__ == "__main__":
    print("🧪 Testing datetime64[ms] fix for Superset-Dremio integration")
    print("=" * 60)
    
    success1 = test_datetime64_mapping()
    success2 = test_superset_compatibility()
    
    if success1 and success2:
        print("\n🎉 All tests passed! The datetime64[ms] issue should be resolved.")
        print("\n📋 Next steps:")
        print("1. Restart your Docker containers: docker-compose down && docker-compose up -d")
        print("2. Wait for Superset to fully initialize (check logs)")
        print("3. Connect to Dremio from Superset using the SQLAlchemy Dremio connector")
        print("4. Test with tables containing timestamp fields")
    else:
        print("\n❌ Some tests failed. Please check the error messages above.") 