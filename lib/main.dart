import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('ok_tally');
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen()));
}

final indianFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final box = Hive.box('ok_tally');
  final _nameController = TextEditingController();
  String _searchQuery = "";
  Set<dynamic> selectedKeys = {}; // Index ki jagah Hive Key use karenge safe deletion ke liye

  void _addCustomer() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("New Customer"),
      content: TextField(controller: _nameController, autofocus: true, decoration: const InputDecoration(hintText: "enter customer name")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
        ElevatedButton(onPressed: () {
          if (_nameController.text.isNotEmpty) {
            // Naye customer ke saath 'lastUpdated' timestamp bhi add kiya hai
            box.add({
              'name': _nameController.text.trim(), 
              'balance': 0.0, 
              'history': [],
              'lastUpdated': DateTime.now().millisecondsSinceEpoch,
            });
            _nameController.clear();
            Navigator.pop(c); 
            setState(() {});
          }
        }, child: const Text("Save")),
      ],
    ));
  }

  void _deleteSelected() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Delete Confirmation"),
      content: Text("Kya aap yeh ${selectedKeys.length} customers delete karna chahte hain?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("No")),
        ElevatedButton(
          onPressed: () {
            for (var key in selectedKeys) { box.delete(key); }
            setState(() { selectedKeys.clear(); });
            Navigator.pop(c);
          }, 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), 
          child: const Text("Yes, Delete")
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedKeys.isEmpty ? "Ok Tally" : "${selectedKeys.length} Selected"),
        backgroundColor: Colors.indigo, foregroundColor: Colors.white,
        actions: [if (selectedKeys.isNotEmpty) IconButton(icon: const Icon(Icons.delete), onPressed: _deleteSelected)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(padding: const EdgeInsets.all(10), child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(hintText: "Search customer...", prefixIcon: const Icon(Icons.search), fillColor: Colors.white, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)),
          )),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box b, _) {
          double netBalance = 0;
          for (var i = 0; i < b.length; i++) { netBalance += (b.getAt(i)['balance'] ?? 0.0); }
          
          // Saare customers ki keys nikal kar unhe 'lastUpdated' ke hisab se sort karenge
          List<dynamic> sortedKeys = b.keys.toList();
          sortedKeys.sort((a, bKey) {
            var custA = b.get(a);
            var custB = b.get(bKey);
            int timeA = custA['lastUpdated'] ?? 0;
            int timeB = custB['lastUpdated'] ?? 0;
            return timeB.compareTo(timeA); // Latest upar aayega
          });

          // Ab sorted keys par search filter lagayenge
          List<dynamic> filteredKeys = [];
          for (var key in sortedKeys) {
            var cust = b.get(key);
            // ✅ FIX 1: Agar search query khali ho ya naam match kare, dono time par saare data show honge
            if (_searchQuery.isEmpty || cust['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) {
              filteredKeys.add(key);
            }
          }

          return Column(
            children: [
              // ✅ FIX 2: Expanded aur safe fontSize lagaya hai taaki bade amounts par yellow strip error na aaye
              Container(
                width: double.infinity, 
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                color: Colors.indigo.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    const Text(
                      "Total Balance:", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        indianFormat.format(netBalance.abs()), 
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 28, 
                          fontWeight: FontWeight.bold, 
                          color: netBalance >= 0 ? Colors.green : Colors.red
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredKeys.length,
                  itemBuilder: (context, index) {
                    var currentKey = filteredKeys[index];
                    var cust = Map<String, dynamic>.from(b.get(currentKey));
                    double bal = cust['balance'] ?? 0.0;
                    bool isS = selectedKeys.contains(currentKey);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), color: isS ? Colors.indigo.shade50 : null,
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: isS ? Colors.red : Colors.indigo, child: isS ? const Icon(Icons.check, color: Colors.white) : Text(cust['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                        title: Text(cust['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        trailing: Text(indianFormat.format(bal.abs()), style: TextStyle(color: bal >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 22)),
                        onLongPress: () => setState(() => selectedKeys.add(currentKey)),
                        onTap: () {
                          if (selectedKeys.isNotEmpty) {
                            setState(() { isS ? selectedKeys.remove(currentKey) : selectedKeys.add(currentKey); });
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (c) => DetailScreen(customerKey: currentKey))).then((v) => setState(() {}));
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addCustomer, backgroundColor: Colors.indigo, child: const Icon(Icons.person_add, color: Colors.white)),
    );
  }
}

class DetailScreen extends StatefulWidget {
  final dynamic customerKey; // Index ke jagah Unique Key use karenge
  const DetailScreen({super.key, required this.customerKey});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final box = Hive.box('ok_tally');
  final _amtCont = TextEditingController();
  final _descCont = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Set<int> selectedTxIndices = {}; 

  void _addTransaction(bool isGiven) {
    double amt = double.tryParse(_amtCont.text.replaceAll(',', '')) ?? 0.0;
    if (amt <= 0) return;
    
    var cust = Map<String, dynamic>.from(box.get(widget.customerKey));
    double newBal = isGiven ? (cust['balance'] ?? 0.0) + amt : (cust['balance'] ?? 0.0) - amt;
    
    List hist = List.from(cust['history'] ?? []);
    hist.add({'amount': amt, 'isGiven': isGiven, 'description': _descCont.text.trim(), 'date': DateFormat('dd MMM, yyyy').format(_selectedDate)});
    
    // Entry save karte waqt 'lastUpdated' ko current time se change kar rhe hain taaki yeh customer top par aa jaye
    box.put(widget.customerKey, {
      'name': cust['name'], 
      'balance': newBal, 
      'history': hist,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    });
    
    _amtCont.clear(); _descCont.clear(); _selectedDate = DateTime.now();
    Navigator.pop(context); 
    setState(() {});
  }

  void _deleteSelectedTx() {
    var cust = Map<String, dynamic>.from(box.get(widget.customerKey));
    List hist = List.from(cust['history']);
    double currentBal = cust['balance'];
    List<int> sorted = selectedTxIndices.toList()..sort((a, b) => b.compareTo(a));
    for (var i in sorted) {
      var tx = hist[i];
      currentBal = tx['isGiven'] ? currentBal - tx['amount'] : currentBal + tx['amount'];
      hist.removeAt(i);
    }
    // Transaction delete hone par bhi list order up to date rahega
    box.put(widget.customerKey, {
      'name': cust['name'], 
      'balance': currentBal, 
      'history': hist,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    });
    setState(() { selectedTxIndices.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    var cust = Map<String, dynamic>.from(box.get(widget.customerKey));
    double bal = cust['balance'] ?? 0.0;
    List hist = cust['history'] ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo, foregroundColor: Colors.white,
        title: selectedTxIndices.isEmpty 
          ? InkWell(
              onTap: () {
                final _e = TextEditingController(text: cust['name']);
                showDialog(context: context, builder: (c) => AlertDialog(
                  title: const Text("Change Name"), content: TextField(controller: _e, autofocus: true),
                  actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () { box.put(widget.customerKey, {...cust, 'name': _e.text.trim()}); Navigator.pop(c); setState(() {}); }, child: const Text("Edit"))],
                ));
              },
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text(cust['name']), const SizedBox(width: 8), const Icon(Icons.edit, size: 16)]),
            )
          : Text("${selectedTxIndices.length} Selected"),
        actions: [if (selectedTxIndices.isNotEmpty) IconButton(icon: const Icon(Icons.delete), onPressed: _deleteSelectedTx)],
      ),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(16), color: Colors.white, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Total Balance:", style: TextStyle(fontSize: 18)), 
          Text(indianFormat.format(bal.abs()), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: bal >= 0 ? Colors.green : Colors.red))
        ])),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(10), itemCount: hist.length, itemBuilder: (c, i) {
          var tx = hist[i];
          bool isG = tx['isGiven'];
          bool isS = selectedTxIndices.contains(i);
          return Align(alignment: isG ? Alignment.centerRight : Alignment.centerLeft, child: GestureDetector(
            onLongPress: () => setState(() => selectedTxIndices.add(i)),
            onTap: () { if (selectedTxIndices.isNotEmpty) setState(() { isS ? selectedTxIndices.remove(i) : selectedTxIndices.add(i); }); },
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75, margin: const EdgeInsets.symmetric(vertical: 6), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isS ? Colors.indigo.shade100 : (isG ? Colors.green.shade50 : Colors.red.shade50),
                borderRadius: BorderRadius.circular(12), border: Border.all(color: isS ? Colors.indigo : (isG ? Colors.green.shade100 : Colors.red.shade100))
              ),
              child: Column(crossAxisAlignment: isG ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                Text(indianFormat.format(tx['amount']), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isG ? Colors.green : Colors.red)),
                if (tx['description'] != null && tx['description'] != "") Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(tx['description'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87))),
                Text(tx['date'], style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ]),
            ),
          ));
        })),
        if (selectedTxIndices.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: ElevatedButton(onPressed: () => _showDialog(false), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text("RECEIVED"))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(onPressed: () => _showDialog(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text("GIVEN"))),
        ])),
      ]),
    );
  }

  void _showDialog(bool isGiven) {
    ValueNotifier<bool> isTyping = ValueNotifier(false);
    _amtCont.addListener(() { isTyping.value = _amtCont.text.isNotEmpty; });

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setPopupState) => AlertDialog(
      title: Text(isGiven ? "Amount Given" : "Amount Received", style: TextStyle(color: isGiven ? Colors.green : Colors.red)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _amtCont, autofocus: true, keyboardType: TextInputType.number, 
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(labelText: "Amount", prefixText: "₹ ", border: OutlineInputBorder())
        ),
        const SizedBox(height: 15),
        InkWell(onTap: () async {
          final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2101));
          if (picked != null) setPopupState(() { _selectedDate = picked; });
        }, child: Row(children: [const Icon(Icons.calendar_today, color: Colors.indigo, size: 20), const SizedBox(width: 10), Text("Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}", style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))])),
      ]),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      actions: [
        ValueListenableBuilder(
          valueListenable: isTyping,
          builder: (context, bool visible, _) {
            return visible ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _descCont, 
                autofocus: false,
                decoration: InputDecoration(
                  labelText: "(Description)", 
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
                )
              ),
            ) : const SizedBox();
          }
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () { _amtCont.clear(); _descCont.clear(); Navigator.pop(context); }, child: const Text("Cancel")),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => _addTransaction(isGiven), 
              style: ElevatedButton.styleFrom(backgroundColor: isGiven ? Colors.green : Colors.red, foregroundColor: Colors.white),
              child: const Text("Save Entry")
            ),
          ],
        ),
      ],
    )));
  }
}