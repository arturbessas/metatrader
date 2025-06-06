//+------------------------------------------------------------------+

//|                                                 SmarttbotAPI.mq5 |

//|                        Artur Bessas (artur.bessas@smarttbot.com) |

//|                                        https://www.smarttbot.com |

//+------------------------------------------------------------------+

#define version 0.1

#include <Csv.mqh>
#include <Generic\HashMap.mqh>

struct DoublePair
{
    double a;
    double b;
};

CHashMap<datetime, DoublePair*> x;

void OnStart()
{
    DoublePair *dp = new DoublePair;
    dp.a = 1.0;
    dp.b = 2.0;

    x.Add(TimeCurrent(), dp);

    // Acessando depois:
    DoublePair result;
    if(x.Get(TimeCurrent(), result))
        Print("a: ", result.a, " b: ", result.b);
}

