## Proyecto

#### Integrantes

* 20000758 - Hector Alberto Heber Mendia Arriola
* 05244028 - Edwin Estuardo Zapeta Gómez

A continuación archivos de referencia a la aplicación:

* [server.r](https://github.com/estuardozapeta/Product-Development-Proyecto/blob/main/server.R)
* [ui.r](https://github.com/estuardozapeta/Product-Development-Proyecto/blob/main/ui.R)

#### **Desarrollo** 

**1. Archivos proveidos**

A continuación se listan los archivos que se trasladaron con la data correspondiente a casos confirmados, muertes y recuperaciones de COVID-19.

* time_series_covid19_confirmed_global.csv
* time_series_covid19_deaths_global.csv
* time_series_covid19_recovered_global.csv

**2. Estructura de la base de datos (PostgreSQL)**

Las tres tablas poseen la misma estructura, se hizo de esta manera por facilidad y manipulación de los datos.

```sql
create table confirmed(
  provincia varchar(50),
  country varchar(50),
  lat numeric(38,8),
  long numeric(38,8),
  dates date,
  value int
);


create table deaths(
  provincia varchar(50),
  country varchar(50),
  lat numeric(38,8),
  long numeric(38,8),
  dates date,
  value int
);


create table recovered(
  provincia varchar(50),
  country varchar(50),
  lat numeric(38,8),
  long numeric(38,8),
  dates date,
  value int
);

```

**3. Transformación de datos y programación de DAG**

El script de python que realiza la transformación requiere de las siguientes librerias, algunas como **pandas** para almacenar los datos en un Dataframe y **airflow** en su mayoría que se encarga de crear workflows de forma programática y, además, planificarlos y monitorizarlos de forma centralizada.

```python
import pandas as pd
from datetime import datetime
from airflow import DAG
from airflow.models import Variable
from airflow.contrib.hooks.fs_hook import FSHook
from airflow.contrib.sensors.file_sensor import FileSensor
from airflow.operators.python_operator import PythonOperator
from airflow.utils.dates import days_ago
from structlog import get_logger
from airflow.hooks.postgres_hook import PostgresHook

```

Se delaran las siguientes variables con valores por defecto para establecer la conexión a la base de datos y para definir el nombre del CSV que contine los datos. Este ejemplo realiza la carga al motor de base de datos Postgres de los casos confirmados a nivel mundial.

```python
FILE_CONNECTION_ID = "filed"
FILE_NAME = "time_series_covid19_confirmed_global.csv"
```

La siguiente función se utiliza para realizar la transformación de los datos. El proceso se encarga de recorrer el archivo CSV, transformar los datos tipo DATE a un formato específico y de sumarizar los valores filtrados por fecha y país.

```python
def etl_process(**kwargs):
    file_path = FSHook(conn_id = FILE_CONNECTION_ID).get_path()
    full_path = f'{file_path}/{FILE_NAME}'
    df = pd.read_csv(full_path, encoding = "ISO-8859-1")
    total_cols = df.keys()
    prov = []
    country = []
    lat = []
    lon = []
    date=[]
    val = []
    fila = 0
    for idx,item in df.iterrows():
        fila += 1
        for coldate in total_cols[4:]:
            prov.append(item['Province/State'])
            country.append(item['Country/Region'])
            lat.append(item['Lat'])
            lon.append(item['Long'])
            date_time_obj = datetime.strptime(coldate, '%m/%d/%y')
            date.append(date_time_obj)
            val.append(item[coldate])
    carga = pd.DataFrame({})
    d = {'provincia':prov, 'country': country, 'lat': lat, 'long': lon, 'dates': date, 'value':val}
    carga = pd.DataFrame(data=d)
    locallog = pd.DataFrame({'tipo':['confirmed'], 'fecha':[datetime.now()]})

    psql_connection = PostgresHook('pgsql').get_sqlalchemy_engine()
    with psql_connection.begin() as connection:
        connection.execute("truncate confirmed")
        carga.to_sql('confirmed', con=connection, if_exists='append', index=False)
        locallog.to_sql('log_carga', con=connection, if_exists='append', index=False)        
```

A continuación se crea el workflow para programar la carga a la base de datos, el proceso consiste en recoger la data transformada e insertarla en la estructura creada en Postgres.

```python       
dag = DAG('confirmed', description='Load COVID confirmed cases',
          default_args={
              'owner': 'hector.mendia',
              'depends_on_past': False,
              'max_active_runs': 1,
              'start_date': days_ago(1)
          },
          schedule_interval='0 1 * * *',
          catchup=True)

file_sensor_task = FileSensor(dag = dag,
                                task_id="readfile_sensor",
                                fs_conn_id=FILE_CONNECTION_ID,
                                filepath=FILE_NAME,
                                poke_intreval=10,
                                timeout=300
                            )

etl_operator = PythonOperator(dag = dag,
                            task_id="etl_confirmed",
                            python_callable =etl_process,
                            provide_context=True
)

file_sensor_task >> etl_operator
```

**4. Shiny App**

**4.1 Vista general de la aplicación**

Al interactuar con los input que se encuentran del lado izquierdo, automáticamente se renderizan los indicadores, gráficas y resto de componentes del panel derecho.

<img src="https://raw.githubusercontent.com/estuardozapeta/Product-Development-Proyecto/main/image-1.png">

**4.2 Contador de casos confirmados, muertes y recuperados**

Los contadores que se muestran en la parte superior de la aplicación se actualizan dependiendo de la fecha o pais seleccionado.

<img src="https://raw.githubusercontent.com/estuardozapeta/Product-Development-Proyecto/main/image-2.png">

**4.3 Mapas interactivos**

Cada mapa despliega un marcador sobre el pais que se selecciona y además al posicionarse por encima de la burbuja devuelve la cantidad de casos confirmados, muertes o recuperados, según sea el caso. El tamaño y color de cada burbuja pintada en el mapa varía dependiendo de la cantidad de casos reportados en cada país.

**4.3.1 Mapa de casos confirmados**

<img src="https://raw.githubusercontent.com/estuardozapeta/Product-Development-Proyecto/main/image-7.png">

**4.3.2 Mapa de muertes**

<img src="https://raw.githubusercontent.com/estuardozapeta/Product-Development-Proyecto/main/image-3.png">

**4.3.3 Mapa de recuperados**

<img src="https://raw.githubusercontent.com/estuardozapeta/Product-Development-Proyecto/main/image-8.png">

**4.4 Tendencia de casos confirmados**

La gráfica de líneas muestra el comportamiento de casos confirmados a lo largo de los meses desde que aparecío la enfermedad.

<img src="https://raw.githubusercontent.com/estuardozapeta/Product-Development-Proyecto/main/image-9.png">

**4.5 Detalle de casos recuperados**

La siguiente tabla muestra el detalle de casos recuperados en un pais específico. En la columna **cantidad** se muestra una franja celeste que varía su intensidad dependiendo del día que más recuperaciones se han presentado.

<img src="https://raw.githubusercontent.com/estuardozapeta/Product-Development-Proyecto/main/image-4.png">