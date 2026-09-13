import pytest
import os
import sys

# add server path
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from server.backtest import run_backtest

def test_run_backtest_example():
    path = os.path.join(os.path.dirname(__file__), '..', 'server', 'example_data.csv')
    # should run without raising
    run_backtest(path)
    assert True
