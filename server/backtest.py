try:
    import pandas as pd
except Exception:
    pd = None
import argparse
import math
import csv
from datetime import datetime

def sma(series, period):
    return series.rolling(period).mean()

def load_csv(path):
    if pd is not None:
        df = pd.read_csv(path, parse_dates=[0])
        df.columns = ['datetime','open','high','low','close','volume']
        df.set_index('datetime', inplace=True)
        return df
    # fallback to simple csv reader returning list-like dicts
    data = []
    with open(path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        headers = next(reader)
        for row in reader:
            dt = datetime.fromisoformat(row[0])
            data.append({
                'datetime': dt,
                'open': float(row[1]),
                'high': float(row[2]),
                'low': float(row[3]),
                'close': float(row[4]),
                'volume': float(row[5])
            })
    return data

def get_recent_sr(df, idx, lookback=50):
    window = df.iloc[max(0, idx-lookback+1):idx+1]
    return window['low'].min(), window['high'].max()

def run_backtest(path, fast=5, slow=20, tp_pips=6, sl_pips=8, risk_pct=1.0, lot_size=0.01, pip=0.0001):
    df = load_csv(path)
    balance = 10000.0
    equity = balance
    trade = None
    trades = []

    # if pandas loaded, convert to lists for faster access
    if pd is not None:
        df['ma_fast'] = sma(df['close'], fast)
        df['ma_slow'] = sma(df['close'], slow)
        length = len(df)
        for i in range(length):
            if i < slow: continue
            row = df.iloc[i]
            prev = df.iloc[i-1]
            ma_fast = row['ma_fast']
            ma_slow = row['ma_slow']
            ma_fast_prev = prev['ma_fast']
            ma_slow_prev = prev['ma_slow']
            support, resistance = get_recent_sr(df, i, 50)
            # entry
            if trade is None and ma_fast>ma_slow and ma_fast_prev<=ma_slow_prev:
                price = row['close']
                sl = price - sl_pips*pip
                tp = price + tp_pips*pip
                trades.append({'side':'buy','entry':price,'sl':sl,'tp':tp,'idx':i})
                trade = trades[-1]
            elif trade is None and ma_fast<ma_slow and ma_fast_prev>=ma_slow_prev:
                price = row['close']
                sl = price + sl_pips*pip
                tp = price - tp_pips*pip
                trades.append({'side':'sell','entry':price,'sl':sl,'tp':tp,'idx':i})
                trade = trades[-1]
            # exits
            if trade is not None:
                h = row['high']
                l = row['low']
                if trade['side']=='buy':
                    if l<=trade['sl']:
                        pl = (trade['sl']-trade['entry'])/pip * -1
                        equity += pl
                        trade.update({'exit':trade['sl'],'pl':pl,'exit_idx':i})
                        trade=None
                    elif h>=trade['tp']:
                        pl = (trade['tp']-trade['entry'])/pip
                        equity += pl
                        trade.update({'exit':trade['tp'],'pl':pl,'exit_idx':i})
                        trade=None
                else:
                    if h>=trade['sl']:
                        pl = (trade['entry']-trade['sl'])/pip * -1
                        equity += pl
                        trade.update({'exit':trade['sl'],'pl':pl,'exit_idx':i})
                        trade=None
                    elif l<=trade['tp']:
                        pl = (trade['entry']-trade['tp'])/pip
                        equity += pl
                        trade.update({'exit':trade['tp'],'pl':pl,'exit_idx':i})
                        trade=None
    else:
        # fallback CSV list-based
        for i in range(len(df)):
            if i < slow: continue
            row = df[i]
            prev = df[i-1]
            # compute simple moving averages manually
            def sma_list(index, period, key='close'):
                s = 0.0
                cnt = 0
                for j in range(index-period+1, index+1):
                    if j<0: continue
                    s += df[j][key]
                    cnt += 1
                return s/cnt if cnt>0 else 0.0
            ma_fast = sma_list(i, fast)
            ma_slow = sma_list(i, slow)
            ma_fast_prev = sma_list(i-1, fast)
            ma_slow_prev = sma_list(i-1, slow)

            support = min([r['low'] for r in df[max(0,i-49):i+1]])
            resistance = max([r['high'] for r in df[max(0,i-49):i+1]])

            if trade is None and ma_fast>ma_slow and ma_fast_prev<=ma_slow_prev:
                price = row['close']
                sl = price - sl_pips*pip
                tp = price + tp_pips*pip
                trades.append({'side':'buy','entry':price,'sl':sl,'tp':tp,'idx':i})
                trade = trades[-1]
            elif trade is None and ma_fast<ma_slow and ma_fast_prev>=ma_slow_prev:
                price = row['close']
                sl = price + sl_pips*pip
                tp = price - tp_pips*pip
                trades.append({'side':'sell','entry':price,'sl':sl,'tp':tp,'idx':i})
                trade = trades[-1]

            if trade is not None:
                h = row['high']
                l = row['low']
                if trade['side']=='buy':
                    if l<=trade['sl']:
                        pl = (trade['sl']-trade['entry'])/pip * -1
                        equity += pl
                        trade.update({'exit':trade['sl'],'pl':pl,'exit_idx':i})
                        trade=None
                    elif h>=trade['tp']:
                        pl = (trade['tp']-trade['entry'])/pip
                        equity += pl
                        trade.update({'exit':trade['tp'],'pl':pl,'exit_idx':i})
                        trade=None
                else:
                    if h>=trade['sl']:
                        pl = (trade['entry']-trade['sl'])/pip * -1
                        equity += pl
                        trade.update({'exit':trade['sl'],'pl':pl,'exit_idx':i})
                        trade=None
                    elif l<=trade['tp']:
                        pl = (trade['entry']-trade['tp'])/pip
                        equity += pl
                        trade.update({'exit':trade['tp'],'pl':pl,'exit_idx':i})
                        trade=None

    # summarize
    closed_trades = [t for t in trades if 'pl' in t]
    wins = [t for t in closed_trades if t['pl']>0]
    losses = [t for t in closed_trades if t['pl']<=0]
    total_pl = sum([t.get('pl',0) for t in closed_trades])
    win_rate = (len(wins)/len(closed_trades))*100 if closed_trades else 0
    avg_win = (sum([t['pl'] for t in wins])/len(wins)) if wins else 0
    avg_loss = (sum([t['pl'] for t in losses])/len(losses)) if losses else 0
    gross_win = sum([t['pl'] for t in wins])
    gross_loss = -sum([t['pl'] for t in losses])
    profit_factor = (gross_win / gross_loss) if gross_loss>0 else float('inf')
    print(f"Trades: {len(trades)} Closed: {len(closed_trades)} Wins: {len(wins)} Losses: {len(losses)} Win%: {win_rate:.1f}%")
    print(f"P/L(pips): {total_pl:.1f} AvgWin: {avg_win:.2f} AvgLoss: {avg_loss:.2f} ProfitFactor: {profit_factor:.2f}")

def walkforward(path, train_size=0.5, step_size=0.1, **kwargs):
    df = load_csv(path)
    n = len(df)
    train_n = int(n * train_size)
    step_n = int(n * step_size)
    start = 0
    results = []
    while start + train_n < n:
        train_slice = df.iloc[start:start+train_n]
        test_slice = df.iloc[start+train_n:start+train_n+step_n]
        # write temp CSVs
        train_csv = 'wf_train.csv'
        test_csv = 'wf_test.csv'
        train_slice.to_csv(train_csv)
        test_slice.to_csv(test_csv)
        # run backtest on test slice
        print(f"Walk-forward window start={start} train_n={train_n} test_n={len(test_slice)}")
        run_backtest(test_csv, **kwargs)
        results.append(True)
        start += step_n

    print("Walk-forward completed")

if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('csv', help='historical OHLC CSV')
    parser.add_argument('--walk', action='store_true', help='run walk-forward')
    args = parser.parse_args()
    if args.walk:
        walkforward(args.csv)
    else:
        run_backtest(args.csv)
