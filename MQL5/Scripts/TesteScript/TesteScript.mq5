//+------------------------------------------------------------------+

//|                                                 SmarttbotAPI.mq5 |

//|                        Artur Bessas (artur.bessas@smarttbot.com) |

//|                                        https://www.smarttbot.com |

//+------------------------------------------------------------------+

#define version 0.1

#include <Csv.mqh>
#include <Generic\HashMap.mqh>


void OnStart()
{
    datetime dt = TimeCurrent() % (60*60*24);
    
    Print(dt);
}

