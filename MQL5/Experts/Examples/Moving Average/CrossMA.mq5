//+------------------------------------------------------------------+
//|                                                      CrossMA.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//--- input parameters
input int      periodocurta;
input int      periodolonga;
input int      periodografico;

int curtaHandle;

double mediaCurta;

double aux[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()

  {

//--- 

      ArraySetAsSeries(aux,true);

      

         

      curtaHandle = iMA(_Symbol,getPeriodoGrafico(periodografico),periodocurta,0,getTipoMedia(),PRICE_CLOSE);


      //ArraySetAsSeries(mediaCurta,true);

      //curtaHandle = iMA(_Symbol,_Period,periodoCurta,0,MODE_SMA,PRICE_CLOSE);



      int fileHandle=FileOpen(ExtFileName,FILE_WRITE|FILE_TXT);

      auxFileHandle = fileHandle;

     // FileWriteString(fileHandle, "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>");

     // FileWriteString(fileHandle, "<MarketData>");

    //  FileWriteString(fileHandle, "<Input>");

     // FileWriteString(fileHandle, "<Ticks>");
     
     
      FileWriteString(fileHandle, "[");

      

      

      Print("Pasta do arquivo: " + terminal_data_path);

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
   
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
