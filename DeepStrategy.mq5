//+------------------------------------------------------------------+
//|                                                 DeepStrategy.mq5 |
//|                                     Copyright 2020, Deepware Srl |
//|                                          https://www.deepware.it |
//+------------------------------------------------------------------+
//--- input parameters
input group "STOC Params";
input int      fast_stoc_slowing=1;
input int      slow_stoc_slowing=3;

input group "STOC thresholds";
input int      overbought_th=80;
input int      oversold_th=20;

input group "Market Time";
input int StartTime = 7;                                       // Time to allow trading to start
input int EndTime = 20;                                        // Time to stop trading

//--- inputs for money
input group "Money";
input double             Money_FixLot_Percent =10.0;           // Percent
input double             Money_FixLot_Lots    =0.1;            // Fixed volume

#define RET_OK     0
#define RET_NOK    1

int stoc_fast_handle;
int stoc_slow_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

   stoc_fast_handle=iStochastic(_Symbol, _Period,14,3,fast_stoc_slowing,MODE_SMA,STO_LOWHIGH);
   stoc_slow_handle=iStochastic(_Symbol, _Period,14,3,slow_stoc_slowing,MODE_SMA,STO_LOWHIGH);
   
   if(stoc_fast_handle==INVALID_HANDLE || stoc_slow_handle==INVALID_HANDLE)
   {
     Print("Unable to create handle for iStochastic");
     return(INIT_FAILED);
   }
   
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   double price_value=SymbolInfoDouble(Symbol(),SYMBOL_BID); // price for opening
   double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);         // point value of 1 pip
   
   // Test inversion
   
   double stoc_fast_0 = iIndicatorGetValue(stoc_fast_handle,0);
   double stoc_slow_0 = iIndicatorGetValue(stoc_slow_handle,0);
   double stoc_fast_1 = iIndicatorGetValue(stoc_fast_handle,2);
   double stoc_slow_1 = iIndicatorGetValue(stoc_slow_handle,2);
   
   bool sell_zone = (stoc_fast_0 < oversold_th) && (stoc_slow_0 < oversold_th) && (stoc_fast_1 < oversold_th) && (stoc_slow_1 < oversold_th);
   bool buy_zone =  (stoc_fast_0 > overbought_th) && (stoc_slow_0 > overbought_th) && (stoc_fast_1 > overbought_th) && (stoc_slow_1 > overbought_th);
   
   bool inv_a= (stoc_fast_0 < stoc_slow_0) && (stoc_fast_1 > stoc_slow_1);
   bool inv_b= (stoc_fast_0 > stoc_slow_0) && (stoc_fast_1 < stoc_slow_1);
   
   // 
   if((inv_a||inv_b) && (sell_zone||buy_zone))
      PrintFormat("[EA] Inversion occured stoc_fast_0: %f stoc_slow_0: %f stoc_fast_1: %f stoc_slow_1: %f",stoc_fast_0,stoc_slow_0,stoc_fast_1,stoc_slow_1);

   
   
  }
//+------------------------------------------------------------------+
//| User Methods                                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| iIndicatorGetValue                                               |
//+------------------------------------------------------------------+

double iIndicatorGetValue(int handle, int index)
{
   double indicator_values[1];
   
   //SetIndexBuffer(ind_size,indicator_values,INDICATOR_DATA);
   
   //ZeroMemory(indicator_values);
   
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); // number of decimal places
//--- reset error code 
   ResetLastError();
//--- fill a part of the iRSI array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle,0,index,1,indicator_values)!=1)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(EMPTY_VALUE);
     }
   //return(NormalizeDouble(indicator_values[index], digits));
   return indicator_values[0];
}

//+------------------------------------------------------------------+
//| CheckBarStatus                                                   |
//+------------------------------------------------------------------+

int CheckBarStatus(int indicator_handle)
{
   int calculated=BarsCalculated(indicator_handle);
   if(calculated<=0)
     {
      PrintFormat("BarsCalculated() returned %d, error code %d",calculated,GetLastError());
      return RET_NOK;
     }
   return RET_OK;
}

//+------------------------------------------------------------------+
//| CheckTradeOnTime                                                 |
//+------------------------------------------------------------------+

int CheckTradeOnTime(void)
{

     MqlDateTime dt_struct;
     datetime dtSer=TimeCurrent(dt_struct);
     if( (dt_struct.hour<=StartTime) || (dt_struct.hour>=EndTime) || dt_struct.day_of_week==0 /* Sunday*/|| dt_struct.day_of_week==6 /*Saturday*/){
            return RET_NOK;
     }
     return RET_OK;

}

//+------------------------------------------------------------------+
//| OpenOrder                                                        |
//+------------------------------------------------------------------+

ulong OpenOrder(long const magic_number, ENUM_ORDER_TYPE typeOrder, double sl, double tp, string order_comment)
{

      double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);         // point
      double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);             // current price for closing LONG
      double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);             

      MqlTradeRequest request={0};
      request.action=TRADE_ACTION_DEAL;               // setting a pending order
      request.magic=magic_number;                     // ORDER_MAGIC
      request.symbol=Symbol();                        // symbol
      request.volume=Money_FixLot_Lots;               // volume in 0.1 lots
      request.sl=sl;                                  // Stop Loss is not specified
      request.tp=tp;                                  // Take Profit is not specified
      request.type=typeOrder;                         // order type 
      request.deviation=5;                            // allowed deviation from the price
      request.type_filling = SYMBOL_FILLING_FOK;///
      
      request.comment=order_comment;
      
      //--- form the order type
      
      //--- send a trade request
      MqlTradeResult result={0};

//--- reset the last error code to zero
   ResetLastError();
//--- send request
   bool success=OrderSend(request,result);
//--- if the result fails - try to find out why
   if(!success)
     {
      int answer=result.retcode;
      Print("[EA] TradeLog: Trade request failed. Error = ",GetLastError());
      switch(answer)
        {
         //--- requote
         case 10004:
           {
            Print("[EA] TRADE_RETCODE_REQUOTE");
            Print("[EA] request.price = ",request.price,"   result.ask = ",
                  result.ask," result.bid = ",result.bid);
            break;
           }
         //--- order is not accepted by the server
         case 10006:
           {
            Print("[EA] TRADE_RETCODE_REJECT");
            Print("[EA] request.price = ",request.price,"   result.ask = ",
                  result.ask," result.bid = ",result.bid);
            break;
           }
         //--- invalid price
         case 10015:
           {
            Print("[EA] TRADE_RETCODE_INVALID_PRICE");
            Print("[EA] request.price = ",request.price,"   result.ask = ",
                  result.ask," result.bid = ",result.bid);
            break;
           }
         //--- invalid SL and/or TP
         case 10016:
           {
            Print("[EA] TRADE_RETCODE_INVALID_STOPS");
            Print("[EA] request.sl = ",request.sl," request.tp = ",request.tp);
            Print("[EA] result.ask = ",result.ask," result.bid = ",result.bid);
            break;
           }
         //--- invalid volume
         case 10014:
           {
            Print("[EA] TRADE_RETCODE_INVALID_VOLUME");
            Print("[EA] request.volume = ",request.volume,"   result.volume = ",
                  result.volume);
            break;
           }
         //--- not enough money for a trade operation 
         case 10019:
           {
            Print("[EA] TRADE_RETCODE_NO_MONEY");
            Print("[EA] request.volume = ",request.volume,"   result.volume = ",
                  result.volume,"   result.comment = ",result.comment);
            break;
           }
         //--- some other reason, output the server response code 
         default:
           {
            Print("[EA] Other answer = ",answer);
           }
        }
     }
        
     return result.deal;

}