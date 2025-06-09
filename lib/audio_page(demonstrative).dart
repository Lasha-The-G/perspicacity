import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_selectionarea/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import 'package:perspicacity/utils/dialog_box.dart';
import 'package:perspicacity/utils/globals.dart';
import 'package:provider/provider.dart';
//import 'package:hive_flutter/adapters.dart';

class AudioPageDemo extends StatefulWidget {
  const AudioPageDemo({super.key});

  @override
  State<AudioPageDemo> createState() => _AudioPageDemoState();
}

class _AudioPageDemoState extends State<AudioPageDemo> {
  String posturl = 'http://localhost:5000/tran';
//   http://192.168.100.3:5000
//   http://192.168.100.3:8000
//   https://vaguely-valid-dove.ngrok-free.app
  String currentFilePath = '';
  File? audioFile;

  void showUserMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void loadFile() async {
    FilePickerResult? loader = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (loader != null) {
      audioFile = File(loader.files.single.path!);
      setState(() {
        currentFilePath = audioFile!.path;
      });
    }
  }

  void sendSummaryLen() async {
    var summaryLength =
        Provider.of<globals>(context, listen: false).summaryLength;
    print(summaryLength);
    var request = await http.post(
        Uri.parse('https://vaguely-valid-dove.ngrok-free.app/slen'),
        //Uri.parse('http://192.168.100.3:80/slen'),
        body: json.encode({'sumLen': summaryLength}));

    var decoded = json.decode(request.body) as Map<String, dynamic>;
    print(decoded['weGood']);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(decoded['weGood']),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // i. Upload the file and get job ID
  void transcribe() async {
    final request = http.MultipartRequest(
      "POST",
      //Uri.parse("http://192.168.100.3:80/tran"),
      Uri.parse("https://vaguely-valid-dove.ngrok-free.app/tran"),
    );
    request.files.add(
      await http.MultipartFile.fromPath("audioFile", audioFile!.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    var decoded = json.decode(response.body) as Map<String, dynamic>;

    // New redis stuff
    final jobId = decoded['job_id'];
    print("Job ID: $jobId");

    showUserMessage('Job ID: $jobId');

    // 2. Poll job status
    const pollInterval = Duration(seconds: 8);
    bool completed = false;

    while (!completed) {
      await Future.delayed(pollInterval);

      final jobResponse = await http.get(
        // Uri.parse("http://192.168.100.3:80/job/$jobId"),
        Uri.parse("https://vaguely-valid-dove.ngrok-free.app/job/$jobId"),
      );
      final jobData = json.decode(jobResponse.body) as Map<String, dynamic>;

      print("Job status: ${jobData['status']}");
      showUserMessage('Job status: ${jobData['status']}');

      if (jobData['status'] == 'finished') {
        //showUserMessage("Job finished");
        Provider.of<globals>(context, listen: false)
            .computedText['transcript'] = jobData['result'];
        Provider.of<globals>(context, listen: false).saveToStorage();
        showUserMessage("Storage updated");
        completed = true;
        setState(() {});
      } else if (jobData['status'] == 'failed') {
        //some error handling in the future here
        print("Job failed! wah wah waaaaah");
        showUserMessage("Job failed");
        completed = true;
      }
    }
  }

  void summarize() async {
    final transcript =
        Provider.of<globals>(context, listen: false).computedText['transcript'];

    final response = await http.post(
      //Uri.parse("http://192.168.100.3:80/summ"),
      Uri.parse("https://vaguely-valid-dove.ngrok-free.app/summ"),
      body: json.encode({"transcript": transcript}),
    );
    print(response.body);

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final jobId = decoded['job_id'];

    showUserMessage("Job id: $jobId");

    const pollInterval = Duration(seconds: 6);
    bool completed = false;

    while (!completed) {
      await Future.delayed(pollInterval);

      final jobResponse =
          //await http.get(Uri.parse("http://192.168.100.3:80/job/$jobId"));
          await http.get(Uri.parse(
              "https://vaguely-valid-dove.ngrok-free.app/job/$jobId"));
      final jobData = json.decode(jobResponse.body) as Map<String, dynamic>;
      showUserMessage("Job status: ${jobData['status']}");

      if (jobData['status'] == 'finished') {
        //showUserMessage("Job finished");
        Provider.of<globals>(context, listen: false).computedText['summary'] =
            jobData['result'];
        Provider.of<globals>(context, listen: false).saveToStorage();
        showUserMessage("Storage updated");
        setState(() {});
        completed = true;
      } else if (jobData['status'] == 'failed') {
        print("Summarization job failed");
        showUserMessage("Job failed");
        completed = true;
      }
    }
  }

  void reformat() async {
    final summary =
        Provider.of<globals>(context, listen: false).computedText['summary'];

    final response = await http.post(
      //Uri.parse("http://192.168.100.3:80/refo"),
      Uri.parse("https://vaguely-valid-dove.ngrok-free.app/refo"),
      body: json.encode({'summary': summary}),
    );

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final jobId = decoded['job_id'];
    showUserMessage("Job ID: $jobId");

    const pollInterval = Duration(seconds: 6);
    bool completed = false;

    while (!completed) {
      await Future.delayed(pollInterval);

      final jobResponse =
          //await http.get(Uri.parse("http://192.168.100.3:80/job/$jobId"));
          await http.get(Uri.parse(
              "https://vaguely-valid-dove.ngrok-free.app/job/$jobId"));
      final jobData = json.decode(jobResponse.body) as Map<String, dynamic>;
      showUserMessage("Job status: ${jobData['status']}");

      if (jobData['status'] == 'finished') {
        //showUserMessage("Job finished");
        Provider.of<globals>(context, listen: false).computedText['formated'] =
            jobData['result'];
        Provider.of<globals>(context, listen: false).saveToStorage();
        showUserMessage("Storage updated");
        setState(() {});
        completed = true;
      } else if (jobData['status'] == 'failed') {
        print("Reformatting job failed");
        showUserMessage("Job failed");
        completed = true;
      }
    }
  }

  void request_param() {
    showDialog(
      context: context,
      builder: (context) {
        return DialogBox(
          sendLen: sendSummaryLen,
        );
      },
    );
  }

  List<bool> isSelected = [true, false, false];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(currentFilePath),
              SizedBox(
                height: 35,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          onPressed: loadFile, child: Text("input File")),
                      ElevatedButton(
                          onPressed: request_param,
                          child: Text("length setting")),
                      ElevatedButton(
                          onPressed: transcribe, child: Text("transcribe")),
                      ElevatedButton(
                          onPressed: summarize, child: Text("summarize")),
                    ],
                  ),
                ]),
              ),
              SizedBox(
                height: 35,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                            onPressed: reformat, child: Text("reformat")),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/mainPage'),
                          child: Text("goto Main pages"),
                        ),
                        ElevatedButton(
                            onPressed:
                                Provider.of<globals>(context, listen: false)
                                    .clearStorage,
                            child: Text("clear storage"))
                      ],
                    ),
                  ],
                ),
              ),
              ToggleButtons(
                children: [
                  Text("transcript"),
                  Text("summary"),
                  Text("formated"),
                ],
                isSelected: isSelected,
                onPressed: (index) {
                  setState(() {
                    for (int i = 0; i < isSelected.length; i++) {
                      isSelected[i] = i == index;
                    }
                  });
                },
              ),
              Expanded(
                child: Container(
                  child: SelectionArea(
                    child: Markdown(
                        data: isSelected[0]
                            ? Provider.of<globals>(context, listen: false)
                                .computedText["transcript"]!
                            : isSelected[1]
                                ? Provider.of<globals>(context, listen: false)
                                    .computedText["summary"]!
                                : Provider.of<globals>(context, listen: false)
                                    .computedText["formated"]!),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
