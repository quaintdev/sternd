import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sternd',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Sternd'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<List<Client>> futureClients;

  @override
  void initState() {
    super.initState();
    _appInit();
  }

  _appInit() async {
    SharedPreferences.getInstance().then((instance) {
      setState(() {
        Util.config['ip'] = instance.getString("ip");
        Util.config['port'] = instance.getInt("port");
        if (Util.config["ip"] != null) {
          futureClients = fetchClients();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
          icon: Icon(Icons.settings),
          onPressed: () {
            TextEditingController controllerIP = TextEditingController();
            TextEditingController controllerPort = TextEditingController();
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Dialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0)),
                      child: Container(
                        height: 240.0,
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              "Configuration",
                              style: TextStyle(fontSize: 24.0),
                            ),
                            TextField(
                              controller: controllerIP,
                              decoration:
                                  InputDecoration(labelText: "Server IP"),
                            ),
                            TextField(
                              controller: controllerPort,
                              decoration: InputDecoration(labelText: "Port"),
                            ),
                            SizedBox(
                              height: 8.0,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                RaisedButton(
                                  child: Text("Submit"),
                                  onPressed: () {
                                    SharedPreferences.getInstance()
                                        .then((instance) {
                                      instance.setString(
                                          "ip", controllerIP.text);
                                      instance.setInt("port",
                                          int.parse(controllerPort.text));
                                      Navigator.of(context).pop();
                                      setState(() {
                                        Util.config['ip'] =
                                            instance.getString("ip");
                                        Util.config['port'] =
                                            instance.getInt("port");
                                        if (futureClients != null)
                                          futureClients = fetchClients();
                                      });
                                    });
                                  },
                                ),
                                SizedBox(
                                  width: 8.0,
                                ),
                                RaisedButton(
                                  child: Text("Cancel"),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _appInit();
                                  },
                                )
                              ],
                            ),
                          ],
                        ),
                      ));
                });
          },
        )
      ]),
      body: Center(
          child: FutureBuilder<List<Client>>(
        future: futureClients,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return CircularProgressIndicator();
          }
          if (snapshot.hasError) {
            print("Error occurred while fetching data");
          }
          List<Client> clients = snapshot.data ?? [];
          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                title: Text(clients[index].ip),
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          _FullScreenDialogDemo(client: clients[index]),
                      fullscreenDialog: true,
                    ),
                  );
                },
              );
            },
          );
        },
      )),
    );
  }
}

class _FullScreenDialogDemo extends StatefulWidget {
  final Client client;

  _FullScreenDialogDemo({this.client});

  @override
  _FullScreenDilogPageState createState() => _FullScreenDilogPageState();
}

class _FullScreenDilogPageState extends State<_FullScreenDialogDemo> {
  Future<List<Website>> futureClientData;

  @override
  void initState() {
    super.initState();
    futureClientData = widget.client.fetchVisitedWebsites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.ip),
      ),
      body: Center(
          child: FutureBuilder<List<Website>>(
        future: futureClientData,
        builder: (context, snapshot) {
          if (Util.config['ip'] == null) {
            print(Util.config['ip']);
            return Text(
                "Please configure grimd server ip/port from settings menu");
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return CircularProgressIndicator();
          }
          if (snapshot.hasError) {
            print("Error occurred while fetching data");
          }
          List<Website> visitedWebsites = snapshot.data ?? [];
          return ListView.builder(
            itemCount: visitedWebsites.length,
            itemBuilder: (BuildContext context, int index) {
              var website = visitedWebsites[index];
              return ListTile(
                title: Text(website.address,
                    style: TextStyle(
                        color: website.isBlocked ? Colors.red : Colors.green)),
                subtitle: Text(website.date.hour.toString() +
                    ":" +
                    website.date.minute.toString()),
                trailing: Switch(
                  onChanged: (bool value) {
                    if (!website.isBlocked)
                      http
                          .get('http://' +
                              Util.config['ip'] +
                              ':' +
                              Util.config['port'].toString() +
                              '/blockcache/set/:key')
                          .then((response) {
                        if (response.statusCode == 200) {
                          setState(() {
                            website.isBlocked =
                                jsonDecode(response.body)['success'];
                          });
                        }
                      });
                    else {
                      http
                          .get('http://' +
                              Util.config['ip'] +
                              ':' +
                              Util.config['port'].toString() +
                              '/blockcache/remove/:key')
                          .then((response) {
                        if (response.statusCode == 200) {
                          setState(() {
                            website.isBlocked =
                                !jsonDecode(response.body)['success'];
                          });
                        }
                      });
                    }
                  },
                  value: website.isBlocked,
                ),
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _FullScreenDialogDemo(),
                      fullscreenDialog: true,
                    ),
                  );
                },
              );
            },
          );
        },
      )),
    );
  }
}

Future<List<Client>> fetchClients() async {
  final response = await http.get('http://' +
      Util.config['ip'] +
      ':' +
      Util.config['port'].toString() +
      '/questioncache/client/');
  List<Client> clientList = List();
  if (response.statusCode == 200) {
    jsonDecode(response.body).forEach((ip) => clientList.add(Client(ip: ip)));
    return clientList;
  } else {
    throw Exception('Failed to load album');
  }
}

class Util {
  static Map<String, dynamic> config = Map();
}

class Client {
  String ip;
  List<Website> visitedWebsites;

  Client({this.ip});

  Future<List<Website>> fetchVisitedWebsites() async {
    final response = await http.get('http://' +
        Util.config['ip'] +
        ':' +
        Util.config['port'].toString() +
        '/questioncache/client/' +
        this.ip);
    if (response.statusCode == 200) {
      visitedWebsites = List();
      jsonDecode(response.body).forEach((website) => visitedWebsites.add(
          Website(
              address: website['query']['name'].toString(),
              visitTime: website['date'],
              isBlocked: website['blocked'])));
      return visitedWebsites.reversed.toList();
    } else {
      throw Exception('Failed to load album');
    }
  }
}

class Website {
  bool isBlocked;
  String address;
  DateTime date;

  Website({this.address, int visitTime, this.isBlocked}) {
    this.date = DateTime.fromMillisecondsSinceEpoch(visitTime * 1000);
  }
}
