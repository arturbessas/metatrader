//+------------------------------------------------------------------+
//|                                                      Metabox.mq5 |
//|                                                         Stratbox |
//|                                              https://stratbox.io |
//+------------------------------------------------------------------+
#property copyright "Stratbox"
#property link      "https://stratbox.io"

#include <Generic\Stack.mqh>
#include "StratClient.mqh"
#define VERSION "1.0.0"


#define LOOP_WAIT 100
#define LOOP_SMAMPLE_SIZE 18000
#define LAST_DEAL_VAR_NAME "STRATBOX_LAST_DEAL"


input group "---- Authentication ----"
input string auth_url = "https://smarttmt5-api-main.gke.staging.smarttbot.com/";
input string api_key = "test";


input group "---- New Deal ----"
input string new_deal_url = "https://smarttmt5-api-main.gke.staging.smarttbot.com/api/v1/copy/deal";

input group "----- Important!! -----"
input group "Do not forget to allow requests to our server"
input group "on Tools -> Options -> Expert Advisors"



StratClient client;
CStack<ulong> new_deals;

ulong total_time;
ulong total_loops;
ulong last_checked_deal;
datetime ea_start_time;

int OnInit()
{
	// create timer
   EventSetMillisecondTimer(LOOP_WAIT);
   
   last_checked_deal = ulong(GlobalVariableGet(LAST_DEAL_VAR_NAME)); // 0 if not exists
   total_time = 0;
   total_loops = 0;
   ea_start_time = TimeCurrent();   
   
   // open_positions = client.get_open_positions()
   // check_open_positions(open_positions)
   
   PrintFormat("Metabox successfully loaded. \nVersion: %s. \nLast checked deal: %d.", VERSION, last_checked_deal);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
	// destroy timer
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
	// used to generate some metrics
   ulong loop_start = GetTickCount64();
   
   HistorySelect(MathMax(TimeCurrent() - 60, ea_start_time), TimeCurrent());
   int total_deals = HistoryDealsTotal();
   
   // Find smallest new deal index
   int new_deal_start = total_deals;
   bool error = false;
   for(int i = total_deals - 1; i >= 0; i--)
   {
      ResetLastError();
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
      {
         Alert(StringFormat("Error selecting deal %d. Error: %d.", i, GetLastError()));
         error = true;
         break;
      }
      else if(deal_ticket <= last_checked_deal)
         break;
      
      new_deals.Push(deal_ticket);
   }

   // Iterate over new deals from the oldest to the newest
   while(new_deals.Count() > 0)
   {
      ulong deal_ticket = new_deals.Pop();     
      last_checked_deal = deal_ticket;
      client.handle_new_deal(deal_ticket);
      GlobalVariableSet(LAST_DEAL_VAR_NAME, deal_ticket);
   }
   
   update_metrics(loop_start);
}

void update_metrics(ulong loop_start)
{
   total_time += GetTickCount64() - loop_start;
   total_loops += 1;
   if(total_loops > LOOP_SMAMPLE_SIZE)
   {
      PrintFormat("Average loop time: %I64u ms.", total_time / total_loops);
      Print("Memory used = ", MQLInfoInteger(MQL_MEMORY_USED), " MB");
      
      total_loops = 0;
      total_time = 0;
   }
}
