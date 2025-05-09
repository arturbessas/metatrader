//+------------------------------------------------------------------+
//|                                                  StratClient.mqh |
//|                                                         Stratbox |
//|                                              https://stratbox.io |
//+------------------------------------------------------------------+
#property copyright "Stratbox"
#property link      "https://stratbox.io"

#define MAX_TRIES 5

struct DealData {
   ulong  ticket;
   ulong  magic_number;
   long   position_id;
   string symbol;
   ulong  time_msc;
   string type;
   string reason;
   double volume;
   double price;
   string entry;
   double profit;
   double swap;
   double commission;
};

class StratClient
{   
public:
   StratClient();
   ~StratClient() {}
	
   void send_new_deal(const DealData &deal);
   void handle_new_deal(ulong deal_ticket);
   string send_request(string url, string type, string headers, string json);

private:
   string build_deal_json(const DealData &deal);
   string get_headers(){return StringFormat("Content-type: application/json \r\n x-api-key: %s", api_key);};
};

StratClient::StratClient(void)
{
   string result = send_request(auth_url, "GET", get_headers(), "");
   
   Print(result);
}

string StratClient::build_deal_json(const DealData &deal)
{
   return StringFormat("{\"ticket\":%llu,\"magic_number\":%llu,\"position_id\":%ld,"
                       "\"symbol\":\"%s\",\"time_msc\":%llu,\"type\":\"%s\","
                       "\"reason\":\"%s\",\"volume\":%.2f,\"price\":%.5f,"
                       "\"entry\":\"%s\",\"profit\":%.2f,\"swap\":%.2f,"
                       "\"commission\":%.2f}",
                       deal.ticket, deal.magic_number, deal.position_id,
                       deal.symbol, deal.time_msc, deal.type,
                       deal.reason, deal.volume, deal.price,
                       deal.entry, deal.profit, deal.swap,
                       deal.commission);
}

void StratClient::send_new_deal(const DealData &deal)
{
   string json = build_deal_json(deal);

   Print("Sending new deal:");
   Print(json);

   string result = send_request(new_deal_url, "POST", get_headers(), json);

   Print("Server response:");
   Print(result);
}

string StratClient::send_request(string url, string type, string headers, string json)
{
   char response[];
   uchar body[];
   StringToCharArray(json, body);
   string result_headers;
   int result_code = 0, tries = 0;
   ulong request_start = GetTickCount64();

   while(result_code != 200 && tries++ < MAX_TRIES)
   {
      result_code = WebRequest(type, url, headers, 5, body, response, result_headers);
      string response_str = CharArrayToString(response);

      if(result_code != 200)
      {
         PrintFormat("Error sending new deal. Tries: %d/%d.\n%d: %s", 
                     tries, MAX_TRIES, result_code, response_str);
         Sleep(250);
      }
   }

   ulong requests_time = GetTickCount64() - request_start;
   PrintFormat("Request took %llu ms over %d tries (avg %.2f ms).",
               requests_time, tries, (double)requests_time / tries);

   string response_str = CharArrayToString(response);

   if(result_code == -1)
   {
      Alert(StringFormat("[Stratbox] Requests to (%s) are not allowed. Please allow it on Tools -> Options -> Expert Advisors.", url));
   }
   else if(result_code != 200)
   {
      Alert(StringFormat("[Stratbox] Error sending deal. Code: %d\nResponse: %s\nURL: %s\nHeaders: %s\nPayload: %s",
                         result_code, response_str, url, headers, json));
   }

   return response_str;
}

void StratClient::handle_new_deal(ulong deal_ticket)
{
   if(!HistoryDealSelect(deal_ticket))
   {
      PrintFormat("Could not select deal with ticket %llu", deal_ticket);
      return;
   }

   DealData deal;
   deal.ticket       = deal_ticket;
   deal.magic_number = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
   deal.position_id  = (long)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   deal.symbol       = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
   deal.time_msc     = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_TIME_MSC);
   deal.type         = EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE));
   deal.reason       = EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON));
   deal.volume       = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
   deal.price        = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   deal.entry        = EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY));
   deal.profit       = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
   deal.swap         = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
   deal.commission   = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);

   send_new_deal(deal);
}
