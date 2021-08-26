//+------------------------------------------------------------------+

//|                                                ExportarDados.mq5 |

//|                        Copyright 2020, MetaQuotes Software Corp. |

//|                                             https://www.mql5.com |

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//| Expert initialization function                                   |

//+------------------------------------------------------------------+

string ativo = Symbol();

string fileName = "dados";

int auxFileHandle;

int fileHandle;

string terminal_data_path = TerminalInfoString(TERMINAL_DATA_PATH);

string teste = "";

int minutPrev = -1;

double pricePrev = -1;

int monthPrev = 0;

string encerra = "{\"d\":\"" + "1996-01-28 18:29:56" + "\"," + "\"p\":" + "-1" + "}]";

int OnInit()

  {
      fileHandle=FileOpen(fileName,FILE_WRITE|FILE_TXT);

      auxFileHandle = fileHandle;         
     
      FileWriteString(fileHandle, "[");          


//---

   return(INIT_SUCCEEDED);

  }

//+------------------------------------------------------------------+

//| Expert deinitialization function                                 |

//+------------------------------------------------------------------+

void OnDeinit(const int reason)

  {
  		FileWriteString(auxFileHandle, encerra);		

      FileClose(auxFileHandle);
      
      
      

  }

//+------------------------------------------------------------------+

//| Expert tick function                                             |

//+------------------------------------------------------------------+

void OnTick()

  {

//---

      MqlTick tick;

      if(!SymbolInfoTick(Symbol(),tick))
         return;               

      teste = "";

      MqlDateTime tempo;

      TimeToStruct(tick.time, tempo);
      
      if(tempo.mon != monthPrev)
      {
      	monthPrev = tempo.mon;
      	FileWriteString(auxFileHandle, encerra);
      	FileClose(auxFileHandle);
      	fileName = "dados" + IntegerToString(tempo.year) + IntegerToString(tempo.mon) + ".json";
      	fileHandle = FileOpen(fileName,FILE_WRITE|FILE_TXT);
      	auxFileHandle = fileHandle;
      	FileWriteString(fileHandle, "[");
      }   

      string tempo_str = IntegerToString(tempo.year) + "-" + IntegerToString(tempo.mon, 2, '0') + "-" + IntegerToString(tempo.day, 2, '0') + " " + IntegerToString(tempo.hour, 2, '0') + ":" + IntegerToString(tempo.min, 2, '0') + ":" + IntegerToString(tempo.sec, 2, '0');     
      
      double atual = tick.last;        
      
      if(atual == pricePrev && tempo.min == minutPrev)
      	return;
      pricePrev = atual;
      minutPrev = tempo.min;   

      teste += "{\"d\":\"" + tempo_str + "\",";

      teste += "\"p\":" + DoubleToString(atual, 1) + "},\n";      

      FileWriteString(auxFileHandle, teste);      

  }

//+------------------------------------------------------------------+
