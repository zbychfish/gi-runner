import requests
import urllib3
import base64
import sys
from bs4 import BeautifulSoup


urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
user=sys.argv[1]
password=sys.argv[2]
encoded_u = base64.b64encode((user + ':' + password).encode()).decode()
session = requests.session()
base_url=sys.argv[3]
url = "https://oauth-openshift.apps."+base_url+"/oauth/token/request"
payload = ""
headers = {
    "Authorization": "Basic "+encoded_u
}
response = session.request("POST", url, data=payload, headers=headers, verify=False)
soup = BeautifulSoup(response.text, "html.parser")
code=soup.find('input', {'name': 'code'}).get('value')
csrf=soup.find('input', {'name': 'csrf'}).get('value')
url = "https://oauth-openshift.apps."+base_url+"/oauth/token/display"
querystring = {"csrf":csrf,"code":code}
response = session.request("POST", url, data=payload, headers=headers, params=querystring, verify=False)
soup = BeautifulSoup(response.text, "html.parser")
print(soup.find('code').text)

