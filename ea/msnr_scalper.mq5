//+------------------------------------------------------------------+
//| MSNR Scalper EA - MSNR-like Support/Resistance + MA scalping     |
//| This version is a simplified MT5-safe scaffold.                    |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.0"

#include <Trade\Trade.mqh>

input int InpFastMA = 5;
input int InpSlowMA = 20;
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5;

input bool TradeOnM1 = true;
input bool TradeOnM5 = true;

input int RiskMode = 1;
input double RiskMinimal = 0.25;
input double RiskAverage = 1.0;
input double RiskMaximum = 5.0;

input double TakeProfitPips = 6.0;
input double StopLossPips = 8.0;
input int MaxTradesPerSymbolPerDay = 50;
input bool ConfirmMultiTF = true;

CTrade trade;
datetime lastTradeTime = 0;
int tradesToday = 0;

double GetRiskPercentByMode()
{
   if(RiskMode==0) return RiskMinimal;
   if(RiskMode==2) return RiskMaximum;
   return RiskAverage;
}

double GetMAValue(string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
{
   return iMA(symbol, tf, period, 0, MODE_SMA, PRICE_CLOSE, shift);
}

double CalculateLotSize(double riskPercent, double slPips)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return 0.01;

   double riskMoney = balance * riskPercent / 100.0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) point = 0.00001;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue <= 0.0) tickValue = 0.0001;

   double slValuePerLot = slPips * point * 10.0;
   if(slValuePerLot <= 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double lots = riskMoney / slValuePerLot;
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0.0) lotStep = 0.01;

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(minLot <= 0.0) minLot = 0.01;

   double normalized = MathFloor(lots / lotStep) * lotStep;
   if(normalized < minLot) normalized = minLot;
   return normalized;
}

bool CheckMultiTimeframeTrend(bool isBuy)
{
   double m5Fast = GetMAValue(_Symbol, PERIOD_M5, InpFastMA, 1);
   double m5Slow = GetMAValue(_Symbol, PERIOD_M5, InpSlowMA, 1);
   double h1Fast = GetMAValue(_Symbol, PERIOD_H1, InpFastMA, 1);
   double h1Slow = GetMAValue(_Symbol, PERIOD_H1, InpSlowMA, 1);

   if(isBuy)
      return (m5Fast > m5Slow && h1Fast > h1Slow);
   return (m5Fast < m5Slow && h1Fast < h1Slow);
}

void PlaceOrder(bool isBuy)
{
   double riskPct = GetRiskPercentByMode();
   double lots = CalculateLotSize(riskPct, StopLossPips);
   if(lots <= 0.0) return;

   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double sl = isBuy ? price - StopLossPips * point * 10.0 : price + StopLossPips * point * 10.0;
   double tp = isBuy ? price + TakeProfitPips * point * 10.0 : price - TakeProfitPips * point * 10.0;

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   bool ok = false;
   if(isBuy)
      ok = trade.Buy(lots, _Symbol, price, sl, tp);
   else
      ok = trade.Sell(lots, _Symbol, price, sl, tp);

   if(ok)
   {
      lastTradeTime = TimeCurrent();
      tradesToday++;
   }
}

int OnInit()
{
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
   if(lastTradeTime > 0 && TimeDay(TimeCurrent()) != TimeDay(lastTradeTime))
      tradesToday = 0;

   if(tradesToday >= MaxTradesPerSymbolPerDay && MaxTradesPerSymbolPerDay > 0)
      return;

   double maFast = GetMAValue(_Symbol, InpTimeframe, InpFastMA, 1);
   double maSlow = GetMAValue(_Symbol, InpTimeframe, InpSlowMA, 1);
   double maFastPrev = GetMAValue(_Symbol, InpTimeframe, InpFastMA, 2);
   double maSlowPrev = GetMAValue(_Symbol, InpTimeframe, InpSlowMA, 2);

   bool buySignal = maFast > maSlow && maFastPrev <= maSlowPrev;
   bool sellSignal = maFast < maSlow && maFastPrev >= maSlowPrev;

   if(TradeOnM1 || TradeOnM5)
   {
      if(buySignal)
      {
         if(ConfirmMultiTF)
         {
            if(!CheckMultiTimeframeTrend(true))
               return;
         }
         PlaceOrder(true);
      }
      else if(sellSignal)
      {
         if(ConfirmMultiTF)
         {
            if(!CheckMultiTimeframeTrend(false))
               return;
         }
         PlaceOrder(false);
      }
   }
}

//+------------------------------------------------------------------+
