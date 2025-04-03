//+------------------------------------------------------------------+
//|                                                      Metabox.mq5 |
//|                                                         Stratbox |
//|                                              https://stratbox.io |
//+------------------------------------------------------------------+
//#property copyright "Stratbox"
//#property link      "https://stratbox.io"
#include "StratClient.mqh"
#define VERSION "1.0.0"
//#property script_show_inputs

#define LOOP_WAIT 1000
#define LOOP_SMAMPLE_SIZE 1000
#define LAST_DEAL_VAR_NAME "STRATBOX_LAST_DEAL"


//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+

StratClient client;

void OnStart()
{
   
   ulong total_time = 0;
   ulong total_loops = 0;
   ulong last_checked_deal = ulong(GlobalVariableGet(LAST_DEAL_VAR_NAME)); // 0 if not exists
   
   // client = StratClient()
   // open_positions = client.get_open_positions()
   // check_open_positions(open_positions)
   
   PrintFormat("Metabox successfully loaded. \nVersion: %s. \nLast checked deal: %d.", VERSION, last_checked_deal);
   while(!IsStopped())
   {
      // generate some metrics
      ulong loop_start = GetTickCount64();
      
      HistorySelect(TimeCurrent() - 60, TimeCurrent());
      int total_deals = HistoryDealsTotal();
      //PrintFormat("Total deals = %d", total_deals);
      
      int new_deal_start = total_deals; // Smallest new deal index
      int i = total_deals - 1;
      while(i >= 0 && HistoryDealGetTicket(i) > last_checked_deal)
      {
         new_deal_start = i;
         i -= 1;
      }
      
      for(int i = new_deal_start; i < total_deals; i++)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         handle_new_deal(deal_ticket);
         last_checked_deal = deal_ticket;
         GlobalVariableSet(LAST_DEAL_VAR_NAME, deal_ticket);
      }
      
      
      total_time += GetTickCount64() - loop_start;
      total_loops += 1;
      if(total_loops % LOOP_SMAMPLE_SIZE == 0)
      {
         PrintFormat("Average loop time: %I64u ms.", total_time / total_loops);
         Print("Memory used = ", MQLInfoInteger(MQL_MEMORY_USED), " MB");
      }
      Sleep(LOOP_WAIT);
   }

   return;
}

void handle_new_deal(ulong deal_ticket)
{
   ResetLastError();
   HistoryDealSelect(deal_ticket);
   Print("Error: ", GetLastError());

   client.send_new_deal(
      deal_ticket,  // ticket
      HistoryDealGetInteger(deal_ticket, DEAL_MAGIC),  // magic_number
      HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID),  // position_id
      HistoryDealGetString(deal_ticket, DEAL_SYMBOL),  // symbol
      HistoryDealGetInteger(deal_ticket, DEAL_TIME_MSC),  // time_msc
      EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE)),  // type
      EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON)),  // reason
      HistoryDealGetDouble(deal_ticket, DEAL_VOLUME),  // volume
      HistoryDealGetDouble(deal_ticket, DEAL_PRICE),  // price
      EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY))  // entry
   );
}