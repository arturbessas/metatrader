//+------------------------------------------------------------------+
//|                                                  StratClient.mqh |
//|                                                         Stratbox |
//|                                              https://stratbox.io |
//+------------------------------------------------------------------+
#property copyright "Stratbox"
#property link      "https://stratbox.io"
#define MAX_TRIES 5

class StratClient
{   
   public:
   
   StratClient(void){};
	~StratClient(){};
	
	void send_new_deal(
	   ulong  ticket,
	   ulong  magic_number,
	   long   position_id,
	   string symbol,
	   ulong   time_msc,
	   string type,
	   string reason,
	   double volume,
	   double price,
	   string entry,
	   double profit,
	   double swap,
	   double commission
	);
	
	void handle_new_deal(ulong deal_ticket);
	string send_request(string url, string headers, string json);
};

void StratClient::send_new_deal(
	   ulong  ticket,
	   ulong  magic_number,
	   long   position_id,
	   string symbol,
	   ulong   time_msc,
	   string type,
	   string reason,
	   double volume,
	   double price,
	   string entry,
	   double profit,
	   double swap,
	   double commission
	)
{
	   string json = "{";
   
      json += StringFormat("\"ticket\":%llu,", ticket);
      json += StringFormat("\"magic_number\":%llu,", magic_number);
      json += StringFormat("\"position_id\":%ld,", position_id);
      json += StringFormat("\"symbol\":\"%s\",", symbol);
      json += StringFormat("\"time_msc\":%llu,", time_msc);
      json += StringFormat("\"type\":\"%s\",", type);
      json += StringFormat("\"reason\":\"%s\",", reason);
      json += StringFormat("\"volume\":%.2f,", volume);
      json += StringFormat("\"price\":%.5f,", price);
      json += StringFormat("\"entry\":\"%s\",", entry);
      json += StringFormat("\"profit\":%.2f,", profit);
      json += StringFormat("\"swap\":%.2f,", swap);
      json += StringFormat("\"commission\":%.2f", commission);
      
      json += "}";
      
      Print("Sending new deal:");
      Print(json);
	
      string result = send_request(new_deal_url, new_deal_headers, json);
      
      Print(result);
}

string StratClient::send_request(string url,string headers,string json)
{
   char response[];
   string result_headers;
   uchar body[];
   StringToCharArray(json, body);
   int result_code = 0, tries = 0;
   
   ulong request_start = GetTickCount64();
	while(result_code != 200 && tries++ < MAX_TRIES)
	{
		result_code = WebRequest("POST", url, headers, 5, body, response, result_headers);
		if(result_code != 200)
		{
			PrintFormat("Error sending new deal. Tries: %d/%d.\n%d: %s", 
			tries, MAX_TRIES, result_code, CharArrayToString(response));
			Sleep(250);
		}
	}
	PrintFormat("Request time: %llu ms.", (GetTickCount64() - request_start) / tries);
	
	if(result_code == -1)
	   Alert(StringFormat("Requests to (%s) are not allowed. Please allow it on Tools -> Options -> Expert Advisors,", url));
	
	else if(result_code != 200)
	{
	   Alert(StringFormat("Error sending new deal. Please contact Stratbox team. \n Code: %d. \n Response: %s \n URL: %s \n Headers: %s \n Body: %s",
	   result_code, CharArrayToString(response), url, headers, json));
	}
	
	return CharArrayToString(response);
}

void StratClient::handle_new_deal(ulong deal_ticket)
{
   HistoryDealSelect(deal_ticket);

   send_new_deal(
      deal_ticket,                                                                           // ticket
      HistoryDealGetInteger(deal_ticket, DEAL_MAGIC),                                        // magic_number
      HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID),                                  // position_id
      HistoryDealGetString(deal_ticket, DEAL_SYMBOL),                                        // symbol
      HistoryDealGetInteger(deal_ticket, DEAL_TIME_MSC),                                     // time_msc
      EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE)),           // type
      EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON)),       // reason
      HistoryDealGetDouble(deal_ticket, DEAL_VOLUME),                                        // volume
      HistoryDealGetDouble(deal_ticket, DEAL_PRICE),                                         // price
      EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY)),         // entry
      HistoryDealGetDouble(deal_ticket, DEAL_PROFIT),                                        // profit
      HistoryDealGetDouble(deal_ticket, DEAL_SWAP),                                          // swap
      HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION)                                     // commission
   );
}