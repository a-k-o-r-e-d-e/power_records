import 'dart:collection';
import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:generator_record/db_helper.dart';
import 'package:generator_record/utils.dart';
import 'package:sqflite/sqflite.dart';

import 'days_page.dart';

class RecordsPage extends StatefulWidget {
  final String whereParams; // This is optional
  final CalendarView calendarView;
  final PowerState powerSource;

  RecordsPage(
      {this.calendarView = CalendarView.Daily,
      this.powerSource = PowerState.Unknown,
      this.whereParams});

  @override
  _RecordsPageState createState() => _RecordsPageState(
      calendarView: calendarView,
      whereParams: whereParams,
      powerSource: powerSource);
}

class _RecordsPageState extends State<RecordsPage> {
  _RecordsPageState(
      {this.calendarView = CalendarView.Daily,
      this.powerSource = PowerState.Unknown,
      this.whereParams});

  final String whereParams; // This is optional
  PowerState powerSource;
  CalendarView calendarView;

  Future<List<Map>> _readDB() async {
    // open the database
    Database database = await DbHelper().database;

    String whereClause = "";

    print("DB Called!!!!!");

    if (powerSource != PowerState.Unknown || whereParams != null) {
      whereClause = "WHERE ";

      if (powerSource != PowerState.Unknown) {
        String stateStr = EnumToString.convertToString(powerSource);
        whereClause += " ${DbHelper.powerSourceCol} = '$stateStr' ";
      }

      if (powerSource != PowerState.Unknown && whereParams != null) {
        whereClause += " AND ";
      }

      // add where clause only if where Params is available
      if (whereParams != null) {
        List split = whereParams.split('-20');
        String querableStr = split[0] + "-" + split[1];
        whereClause += " ${DbHelper.startDateCol} LIKE '%$querableStr'";
      }
    }

    String queryStr =
        "SELECT ${DbHelper.startDateCol}, ${DbHelper.powerSourceCol},"
        " SUM(${DbHelper.durationInMinsCol}) ${DbHelper.durationInMinsCol} "
        " FROM ${DbHelper.mainRecordTable}"
        " $whereClause"
        " GROUP BY ${DbHelper.startDateCol}, ${DbHelper.powerSourceCol}"
        " ORDER BY ${DbHelper.startDateTimeCol} DESC";

    // Get the records
    List<Map> daysList = await database.rawQuery(queryStr);

    return daysList;
  }

  LinkedHashMap<String, Map<PowerState, int>> _buildForDays(
      AsyncSnapshot<List<Map>> snapshot) {
    LinkedHashMap<String, Map<PowerState, int>> map =
    LinkedHashMap<String, LinkedHashMap<PowerState, int>>();

    snapshot.data.forEach((element) {
      String date = element[DbHelper.startDateCol];
      PowerState powerState = EnumToString.fromString(
          PowerState.values, element[DbHelper.powerSourceCol]);

      if (!map.containsKey(date)) {
        map[date] = {
          PowerState.Nepa: 0,
          PowerState.Big_Gen: 0,
          PowerState.Small_Gen: 0,
        };
      }

      // String powerSource = powerSourceMap[powerState];

      map[date][powerState] = element[DbHelper.durationInMinsCol];
    });

    return map;
  }

  LinkedHashMap<String, Map<PowerState, int>> _buildForMonths(
      AsyncSnapshot<List<Map>> snapshot) {
    LinkedHashMap<String, Map<PowerState, int>> map =
        LinkedHashMap<String, LinkedHashMap<PowerState, int>>();

    snapshot.data.forEach((element) {
      String date = element[DbHelper.startDateCol];
      List dateSplit = date.split("-");
      String monthYear = dateSplit[1] + "-20" + dateSplit[2];
      PowerState powerState = EnumToString.fromString(
          PowerState.values, element[DbHelper.powerSourceCol]);

      if (!map.containsKey(monthYear)) {
        map[monthYear] = {
          PowerState.Nepa: 0,
          PowerState.Big_Gen: 0,
          PowerState.Small_Gen: 0,
        };
      }
      int previousDuration = map[monthYear][powerState];

      map[monthYear][powerState] =
          previousDuration + element[DbHelper.durationInMinsCol];
    });

    return map;
  }

  _buildSummaryCard(String dateOrMonth, Map<PowerState, int> durationMap) {
    return InkWell(
      onTap: () {
        print("Power Source: $powerSource");
        print("dateOrMonth: $dateOrMonth");

        if (calendarView == CalendarView.Monthly) {
          print("Power Source: $powerSource");
          print("dateOrMonth: $dateOrMonth");

          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => RecordsPage(
                    calendarView: CalendarView.Daily,
                    powerSource: powerSource,
                    whereParams: dateOrMonth,
                  )));
        } else if (calendarView == CalendarView.Daily) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) =>
                  SingleDayRecordPage(
                    dateStr: dateOrMonth,
                    powerSource: powerSource,
                  )));
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateOrMonth,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.primaries[
                          Random().nextInt(Colors.primaries.length)])),
              Visibility(
                visible: powerSource == PowerState.Nepa ||
                    powerSource == PowerState.Unknown,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${powerSourceMap[PowerState.Nepa]}: ",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "${durationInHoursAndMins(Duration(minutes: durationMap[PowerState.Nepa]))}",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Visibility(
                visible: powerSource == PowerState.Small_Gen ||
                    powerSource == PowerState.Unknown,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${powerSourceMap[PowerState.Small_Gen]}: ",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "${durationInHoursAndMins(Duration(minutes: durationMap[PowerState.Small_Gen]))}",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Visibility(
                visible: powerSource == PowerState.Big_Gen ||
                    powerSource == PowerState.Unknown,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${powerSourceMap[PowerState.Big_Gen]}: ",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "${durationInHoursAndMins(Duration(minutes: durationMap[PowerState.Big_Gen]))}",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget powerSourceSelectionCard() {
    return Card(
      margin: const EdgeInsets.all(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  powerSource = PowerState.Unknown;
                });
              },
              child: Container(
                  decoration: BoxDecoration(
                      color: powerSource == PowerState.Unknown
                          ? Colors.green
                          : Colors.grey,
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Text("All"),
                  )),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  powerSource = PowerState.Nepa;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                    color: powerSource == PowerState.Nepa
                        ? Colors.green
                        : Colors.grey,
                    borderRadius: BorderRadius.all(Radius.circular(20))),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Text("Nepa"),
                ),
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  powerSource = PowerState.Big_Gen;
                });
              },
              child: Container(
                  decoration: BoxDecoration(
                      color: powerSource == PowerState.Big_Gen
                          ? Colors.green
                          : Colors.grey,
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Text("Big Gen"),
                  )),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  powerSource = PowerState.Small_Gen;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                    color: powerSource == PowerState.Small_Gen
                        ? Colors.green
                        : Colors.grey,
                    borderRadius: BorderRadius.all(Radius.circular(20))),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Text("Small Gen"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Records Page'),
        actions: [buildHomeButton(context)],
      ),
      body: Column(
        children: [
          // Card for Power Source Selection
          powerSourceSelectionCard(),
          // Card for Calendar View Selection
          if (whereParams == null)
            Card(
              margin: const EdgeInsets.all(6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          calendarView = CalendarView.Daily;
                        });
                      },
                      child: Container(
                          decoration: BoxDecoration(
                              color: calendarView == CalendarView.Daily
                                  ? Colors.green
                                  : Colors.grey,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(20))),
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Text("Daily"),
                          )),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          calendarView = CalendarView.Monthly;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            color: calendarView == CalendarView.Monthly
                                ? Colors.green
                                : Colors.grey,
                            borderRadius:
                                BorderRadius.all(Radius.circular(20))),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Text("Monthly"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map>>(
              future: _readDB(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data.isEmpty) {
                    return Center(
                      child: Text(
                          "No Records found in Database for this Power Source !!"),
                    );
                  }

                  LinkedHashMap<String, Map<PowerState, int>> map;

                  if (calendarView == CalendarView.Monthly) {
                    map = _buildForMonths(snapshot);
                  } else if (calendarView == CalendarView.Daily) {
                    map = _buildForDays(snapshot);
                  }

                  List<Widget> list = List();

                  map.forEach((dateOrMonth, durationMap) {
                    // Duration duration = Duration(minutes: value);

                    list.add(_buildSummaryCard(dateOrMonth, durationMap));
                  });

                  return ListView(
                    children: list,
                  );
                }

                return Center(
                  child: CircularProgressIndicator(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
