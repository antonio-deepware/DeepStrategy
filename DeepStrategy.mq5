//+------------------------------------------------------------------+
//|                                                 DeepStrategy.mq5 |
//|                                     Copyright 2020, Deepware Srl |
//|                                          https://www.deepware.it |
//+------------------------------------------------------------------+

//--- inputs for expert
input string             Expert_Title           = "DeepStrategy";  // Document name
ulong                    Expert_MagicNumber     = 26850;          // Magic Namber

//--- input parameters
input group "STOC Params";
input int               fast_stoc_slowing       = 1;
input int               slow_stoc_slowing       = 3;

input group "Market thresholds";
input int               overbought_th           = 80;
input int               oversold_th             = 20;

input group "RSI Params";
input int               rsi_period              = 14;

input group "Market Time";
input int               StartTime               = 7;                                       // Time to allow trading to start
input int               EndTime                 = 20;                                        // Time to stop trading

//--- inputs for money
input group "Money";
input double             Money_FixLot_Percent   = 10.0;           // Percent
input double             Money_FixLot_Lots      = 0.1;            // Fixed volume

#define RET_OK     0
#define RET_NOK    -1

int stoc_fast_handle;
int stoc_slow_handle;
int rsi_handle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

   stoc_fast_handle = iStochastic(_Symbol, _Period,14,3,fast_stoc_slowing,MODE_SMA,STO_LOWHIGH);
   stoc_slow_handle = iStochastic(_Symbol, _Period,14,3,slow_stoc_slowing,MODE_SMA,STO_LOWHIGH);
   rsi_handle = iRSI(_Symbol, _Period,rsi_period,PRICE_CLOSE);
   
   if(stoc_fast_handle==INVALID_HANDLE || stoc_slow_handle==INVALID_HANDLE || rsi_handle==INVALID_HANDLE)
   {
     Print("Unable to create handle for iStochastic or iRSI");
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
      IndicatorRelease(stoc_fast_handle);
      IndicatorRelease(stoc_slow_handle);
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   double price_value = SymbolInfoDouble(Symbol(),SYMBOL_BID); // price for opening
   double point = SymbolInfoDouble(Symbol(),SYMBOL_POINT);         // point value of 1 pip
   
   // Test inversion
   
   double stoc_fast_0 = iIndicatorGetValue(stoc_fast_handle,0);      // stochastic fast last value
   double stoc_slow_0 = iIndicatorGetValue(stoc_slow_handle,0);      // stochastic slow last value
   double stoc_fast_1 = iIndicatorGetValue(stoc_fast_handle,1);      // stochastic fast previous value
   double stoc_slow_1 = iIndicatorGetValue(stoc_slow_handle,1);      // stochastic slow previous value
   
   double rsi_value_0 = iIndicatorGetValue(rsi_handle,0);      // RSI last value
   double rsi_value_1 = iIndicatorGetValue(rsi_handle,1);      // RSI previous value
   
   bool stoc_buy_zone = (stoc_fast_0 < oversold_th) && (stoc_slow_0 < oversold_th) && (stoc_fast_1 < oversold_th) && (stoc_slow_1 < oversold_th);
   bool stoc_sell_zone =  (stoc_fast_0 > overbought_th) && (stoc_slow_0 > overbought_th) && (stoc_fast_1 > overbought_th) && (stoc_slow_1 > overbought_th);
   
   bool stoc_buy  = (stoc_fast_0 < stoc_slow_0) && (stoc_fast_1 > stoc_slow_1);
   bool stoc_sell = (stoc_fast_0 > stoc_slow_0) && (stoc_fast_1 < stoc_slow_1);
   
   bool rsi_buy   = (rsi_value_1<oversold_th) && (rsi_value_0>oversold_th);         
   bool rsi_sell  = (rsi_value_1>overbought_th) && (rsi_value_0<overbought_th);
   
   /*
      if ( rsi_buy
      )
      PrintFormat("[EA] BUY rsi_value_0 %f rsi_value_1 %f",rsi_value_0,rsi_value_1);
      
      if ( rsi_sell
      )
      PrintFormat("[EA] SELL rsi_value_0 %f rsi_value_1 %f",rsi_value_0,rsi_value_1);
      */
   

   if (  stoc_buy_zone
         && stoc_buy 
         && PositionsTotal()==0
      )
      {
         // LONG
         
         //double sl=iLow(NULL,0,1);
         //double tp = price_value + (((int)((price_value - sl)/point)*2)*point);
         double sl=0;
         double tp=0;
         
         OpenPosition(Expert_MagicNumber, ORDER_TYPE_BUY,sl,tp,"[EA] Enter Buy");
         PrintFormat("[EA] long: stoc_fast_0: %f stoc_slow_0: %f stoc_fast_1: %f stoc_slow_1: %f",stoc_fast_0,stoc_slow_0,stoc_fast_1,stoc_slow_1);
      }
      
      
   if (  stoc_sell_zone 
         && stoc_sell
         && PositionsTotal()==0
      )
      {
      
         // SHORT
         //double sl=iHigh(NULL,0,1);
         //double tp = price_value - (((int)((sl - price_value)/point)*2)*point);
         double sl=0;
         double tp=0;
         
         OpenPosition(Expert_MagicNumber, ORDER_TYPE_SELL,sl,tp,"[EA] Enter Sell");
         PrintFormat("[EA] short: stoc_fast_0: %f stoc_slow_0: %f stoc_fast_1: %f stoc_slow_1: %f",stoc_fast_0,stoc_slow_0,stoc_fast_1,stoc_slow_1);
      }
      
      // Check if open position must be closed!
      int total_pos=PositionsTotal();

      for(int i=total_pos-1; i>=0; i--)
      {
      
            ulong ticket=PositionGetTicket(i);
            
            PositionSelectByTicket(ticket);
            
            ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // type of the position
            ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // MagicNumber of the position
            
            if(magic!=Expert_MagicNumber)
            {
                  break;
            }
            
            if(type==POSITION_TYPE_BUY)
            {
                  if(stoc_sell_zone||stoc_sell)
                  {
                        ClosePosition(Expert_MagicNumber, ticket, "[EA] Close BUY");
                        PrintFormat("[EA] close long: stoc_fast_0: %f stoc_slow_0: %f stoc_fast_1: %f stoc_slow_1: %f",stoc_fast_0,stoc_slow_0,stoc_fast_1,stoc_slow_1);
                  }
                 
            }else if(type==POSITION_TYPE_SELL)
            {
                  if(stoc_buy_zone||stoc_buy)
                  {
                        ClosePosition(Expert_MagicNumber, ticket, "[EA] Close SELL");
                        PrintFormat("[EA] close short: stoc_fast_0: %f stoc_slow_0: %f stoc_fast_1: %f stoc_slow_1: %f",stoc_fast_0,stoc_slow_0,stoc_fast_1,stoc_slow_1);
                  }
                        
                  
            }else
            {
                  PrintFormat("[EA] Invalid position Type. Ticket: #%I64d",ticket);
                  return;
            }
                  
            }

   
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
   return(NormalizeDouble(indicator_values[0], digits));
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
   return calculated;
}

//+------------------------------------------------------------------+
//| CheckTradeOnTime                                                 |
//+------------------------------------------------------------------+

bool CheckTradeOnTime(void)
{

     MqlDateTime dt_struct;
     datetime dtSer=TimeCurrent(dt_struct);
     if( (dt_struct.hour<=StartTime) || (dt_struct.hour>=EndTime) || dt_struct.day_of_week==0 /* Sunday*/|| dt_struct.day_of_week==6 /*Saturday*/){
            return false;
     }
     return true;

}

//+------------------------------------------------------------------+
//| isNewBar                                                         |
//+------------------------------------------------------------------+

bool isNewBar(void){

   static datetime m_prev_bars=0;

   datetime time_0=iTime(_Symbol, _Period,0);
   
   if(time_0==m_prev_bars)
      return false;
   
   m_prev_bars=time_0;
   
   return true;
}

//+------------------------------------------------------------------+
//| Open/Close Position                                                       |
//+------------------------------------------------------------------+

bool OpenPosition(long const magic_number, ENUM_ORDER_TYPE typeOrder, double sl, double tp, string order_comment)
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
       //--- notify about the unsuccessful result of the trade request by returning false
      return(false);
     }
        
     //--- OrderSend() returns true - repeat the answer
     return(true);

}

bool ClosePosition(long const magic_number, ulong  position_ticket, string order_comment)
{

      PositionSelectByTicket(position_ticket);

      double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);         // point
      
      double volume=PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // type of the position             

      MqlTradeRequest request={0};
      
      request.action          = TRADE_ACTION_DEAL;        // type of trade operation
      request.position        = position_ticket;          // ticket of the position
      request.symbol          = Symbol();          // symbol 
      request.volume          = volume;                   // volume of the position
      request.deviation       = 5;                        // allowed deviation from the price
      request.magic           = magic_number;       // MagicNumber of the position
      request.type_filling    = SYMBOL_FILLING_FOK;///
      
      request.comment=order_comment;
      
      if(type==POSITION_TYPE_BUY)
      {
           request.price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
           request.type =ORDER_TYPE_SELL;
           
      }else if(type==POSITION_TYPE_SELL)
      {
           request.price=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
           request.type =ORDER_TYPE_BUY;
      }else
      {
            Print("[EA] Invalid position Type");
            return false;
      }
      
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
       //--- notify about the unsuccessful result of the trade request by returning false
      return(false);
     }
        
     //--- OrderSend() returns true - repeat the answer
     return(true);
}