from gradio_client import Client, handle_file

client = Client("akhaliq/DeepSeek-OCR")
result = client.predict(
	image_input=handle_file('https://raw.githubusercontent.com/zzzDavid/ICDAR-2019-SROIE/master/data/img/X51005255528.jpg'),
	task_type="ocr",
	preset="gundam",
	api_name="/ocr_process"
)
print(result)
