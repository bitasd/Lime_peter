## This peice of the code does the SHORTEST NETWORK PATH between pairs of OD for bike trips using "bike" profile 
## Strictions on the trip length that can be traveled by foot should be appiled (i.e. less than a mile)
## we will exclude trips with OD within 400 (m) with trip length more than triple

import pandas , requests, json, time
import multiprocessing, os, re, sys
import warnings
warnings.filterwarnings('ignore')


def routing_network(lat_o, lon_o, lat_d, lon_d):
    headers = { "content-type": "application/json" }
    start=[lon_o, lat_o]
    end=[lon_d, lat_d]
    priorityJson = {'road_class': {'motorway': 0.00, '*': 1}}

    
    
    route_url = 'http://localhost:8989/route-custom?'
    route = requests.post(url=route_url,headers=headers, json={'profile':'bikef', 'points':[start,end], 'points_encoded':False, 'elevation':False, 'priority': priorityJson,
                                                               'max_speed_fallback': 0.01}).json()
    try:
        # print(route)
        coordinates = route['paths'][0]['points']['coordinates']
        distance = route['paths'][0]['distance']
        duration = route['paths'][0]['time']
        return (coordinates, distance, duration)
    except:

        return (route)
        print ([],[],[])


def extract_point(matched_point):
    
    lon, lat = re.match(r"(.*)\((.*)\)" ,matched_point).groups()[-1].split(" ")
    return lon, lat


def route_modeler(df): 
    
    df[['f_coordinates', 'f_distance', 'f_duration']] = df.apply(lambda row: pandas.Series(routing_network(row['lat_o'], row['lon_o'], row['lat_d'], row['lon_d'])), axis=1)
    df['dist_ratio'] = df['dist_calc']/df['f_distance']
    print(df)
    return df


def processor(df, folder, name):
    
    routed_df = route_modeler(df)
    df.to_csv(f"/mnt/c/Users/bitas/folders/Research/lime/peter/data/detour/{folder}/csv_files/{name}.csv", index = False)
    route_linesCollection = csv_tojson(routed_df)
    json_temp = json.dumps(route_linesCollection)
    f = open(f"/mnt/c/Users/bitas/folders/Research/lime/peter/data/detour/{folder}/json_files/{name}.json","w")
    f.write(json_temp)
    f.close()
    print('done')


def csv_tojson(df):
    linesCollection = dict(type="FeatureCollection", features=[])
    for i in range(len(df)):
        print(i)
        propertDict = dict(
            trip_id= df['trip_id'].tolist()[i],
            dist_calc = df['dist_calc'].tolist()[i],
            f_distance = df['f_distance'].tolist()[i],
            dist_ratio = df['dist_ratio'].tolist()[i],
            propulsion_type = df['propulsion_type'].tolist()[i],
            lat_o = df['lat_o'].tolist()[i],
            lon_o = df['lon_o'].tolist()[i],
            lat_d = df['lat_d'].tolist()[i],
            lon_d = df['lon_d'].tolist()[i]
 )
        linegeo = dict(type="LineString",coordinates=[])
        for f in df['f_coordinates'].tolist()[i]:
            # print(f)
            linegeo['coordinates'].append(f)
        linefeature = dict(type="feature", geometry=linegeo, properties=propertDict)
        linesCollection['features'].append(linefeature)
    return linesCollection




if __name__ == '__main__':

    NUMTHREADS = 1
    NUMLINES = 50
    df_num = sys.argv[1]
    df = pandas.read_csv(f'/mnt/c/Users/bitas/folders/Research/lime/peter/data/detour/{df_num}/{df_num}_startend_error70.csv')

    df[['lon_o', 'lat_o']] = df.apply(lambda row: pandas.Series(extract_point(row['matched_start'])), axis=1)
    df[['lon_d', 'lat_d']] = df.apply(lambda row: pandas.Series(extract_point(row['matched_end'])), axis=1)
    N = len(df)
    
    print(N)

    pool = multiprocessing.Pool(processes=NUMTHREADS)
    pool.starmap(
        processor,
        [
        (df.iloc[line:line + NUMLINES], df_num, line)

        for line in range(0, N, NUMLINES)
        ]
        )

    pool.close()
    pool.join()
