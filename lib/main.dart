import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'seoul_page.dart';
import 'seoul_list_page.dart';

void main() {
  runApp(CityExplorerApp());
}

class CityExplorerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
      ),
      home: CitySelectionPage(),
    );
  }
}

class CitySelectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text("VoAIger, Your Personal Guide"),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Choose a City You're Visiting",
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
              ),
            ),
            SizedBox(height: 16),
            _buildSectionTitle(context, 'Korea'),
            _buildCityGrid(
                context, ['Seoul', 'Busan', 'Incheon', 'Jeju Island']),
            SizedBox(height: 32),
            _buildSectionTitle(context, 'USA'),
            _buildCityGrid(context, ['San Francisco', 'New York', 'Los Angeles', 'Chicago']),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        title,
        style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
      ),
    );
  }

  Widget _buildCityGrid(BuildContext context, List<String> cities) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        itemCount: cities.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 2.5,
        ),
        itemBuilder: (context, index) {
          return CupertinoButton(
            color: CupertinoColors.systemGrey4,
            padding: EdgeInsets.all(16.0),
            onPressed: () {
              if (cities[index] == 'Seoul') {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => SeoulPage(),
                  ),
                );
              } else {}
            },
            child: Text(
              cities[index],
              style: TextStyle(color: CupertinoColors.black),
            ),
          );
        },
      ),
    );
  }
}
